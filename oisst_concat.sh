#!/usr/bin/env bash
# =============================================================================
# Copyright 2026 ARC Centre of Excellence for Weather of the 21st Century
# 
# author: Samuel Green <sam.green@unsw.edu.au>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================
# oisst_concat.sh
# Concatenate daily OISST AVHRR NetCDF files into a single yearly file,
# rechunk with ncks, and stamp the global history attribute.
#
# Usage:
#   ./oisst_concat.sh -y <year> [-v]
#
# Dependencies: cdo, nco (ncks, ncatted)
#
# Date created:
# 2026-04-21
# Last change:
# 2026-04-21
# =============================================================================

set -euo pipefail

trap 'log "FATAL: script exited unexpectedly at line ${LINENO} (exit code $?)"' ERR

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
readonly URL='https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/'
readonly FILE_PREFIX='oisst-avhrr-v02r01.'
readonly FILE_SUFFIX='.nc'
readonly PRELIM_SUFFIX='_preliminary.nc'
readonly PATH_BASE='/g/data/jt48/aus-ref-clim-data-nci/oisst/data/tmp'
readonly PATH_OUT='/g/data/jt48/aus-ref-clim-data-nci/oisst/data/yearly'
readonly LOG_FILE='concat_log.txt'

# CDO/NCO parameters — adjust chunk sizes here if needed
readonly CDO_COMPRESS='zip_5'
readonly CHUNK_TIME=366
readonly CHUNK_LAT=720
readonly CHUNK_LON=720

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
YEAR=''
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--year)
            YEAR="${2:?'--year requires an argument'}"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            die "Unknown argument: $1  (run with -h for help)"
            ;;
    esac
done

[[ -n "${YEAR}" ]] || die "Year is required (-y <year>)"
[[ "${YEAR}" =~ ^[0-9]{4}$ ]] || die "Year must be a 4-digit integer, got: ${YEAR}"

# -----------------------------------------------------------------------------
# Derived paths
# -----------------------------------------------------------------------------
readonly DIR_YEAR="${PATH_BASE}/${YEAR}"
readonly TMP_FILE="${PATH_OUT}/oisst-avhrr-v02r01_${YEAR}_tmp.nc"
readonly OUT_FILE="${PATH_OUT}/oisst-avhrr-v02r01_${YEAR}.nc"
readonly IN_GLOB="${DIR_YEAR}/${FILE_PREFIX}${YEAR}*.nc"

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------
check_deps() {
    local missing=()
    for cmd in cdo ncks ncatted date; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"
}

# -----------------------------------------------------------------------------
# Remove preliminary files superseded by final files
# -----------------------------------------------------------------------------
rm_prelim() {
    local year="$1"
    local dir="${PATH_BASE}/${year}"
    local removed=0

    log "Scanning for superseded preliminary files in ${dir} ..."

    local today_year
    today_year="$(date +%Y)"

    local start_ymd="${year}-01-01"
    local end_ymd

    if [[ "${year}" -eq "${today_year}" ]]; then
        end_ymd="$(date '+%Y-%m-%d')"
    else
        end_ymd="$((year + 1))-01-01"
    fi

    local current
    current="$(date -d "${start_ymd}" '+%Y%m%d')"
    local end_fmt
    end_fmt="$(date -d "${end_ymd}" '+%Y%m%d')"

    while [[ "${current}" < "${end_fmt}" ]]; do
        local final_file="${dir}/${FILE_PREFIX}${current}${FILE_SUFFIX}"
        local prelim_file="${dir}/${FILE_PREFIX}${current}${PRELIM_SUFFIX}"

        if [[ -f "${final_file}" && -f "${prelim_file}" ]]; then
            [[ "${VERBOSE}" == true ]] && log "  Removing: ${prelim_file}"
            rm -f "${prelim_file}"
            (( removed++ )) || true
        fi

        current="$(date -d "${current} +1 day" '+%Y%m%d')"
    done

    log "Removed ${removed} superseded preliminary file(s)."
}

# -----------------------------------------------------------------------------
# Concatenate, rechunk, and annotate
# -----------------------------------------------------------------------------
concat_rechunk() {
    log "Starting concatenation for year ${YEAR} ..."

    # Verify there is at least one source file
    local file_count
    file_count="$(find "${DIR_YEAR}" -name "${FILE_PREFIX}${YEAR}*.nc" 2>/dev/null | wc -l)"
    [[ "${file_count}" -gt 0 ]] || die "No source files found matching: ${IN_GLOB}"
    log "Found ${file_count} daily file(s) to concatenate."

    # Remove stale output files so cdo/ncks don't complain
    if [[ -f "${OUT_FILE}" ]]; then
        log "Removing existing output: ${OUT_FILE}"
        rm -f "${OUT_FILE}"
    fi
    [[ -f "${TMP_FILE}" ]] && rm -f "${TMP_FILE}"

    # --- CDO concatenation ---
    local cmd_cat
    cmd_cat="cdo --no_history -O -L --sortname -f nc4 -z ${CDO_COMPRESS} cat ${IN_GLOB} ${TMP_FILE}"
    log "Running CDO: ${cmd_cat}"
    eval "${cmd_cat}" || die "CDO concatenation failed"
    log "Concatenation complete."

    # --- NCO rechunking ---
    local cmd_chunk
    cmd_chunk="ncks --cnk_dmn time,${CHUNK_TIME} --cnk_dmn lat,${CHUNK_LAT} --cnk_dmn lon,${CHUNK_LON} ${TMP_FILE} ${OUT_FILE}"
    log "Running ncks: ${cmd_chunk}"
    eval "${cmd_chunk}" || die "ncks rechunking failed"
    rm -f "${TMP_FILE}"
    log "Rechunking complete."

    # --- Stamp history attribute ---
    local hist="Downloaded original files from ${URL}. CDO concatenation: ${cmd_cat}. NCO rechunking: ${cmd_chunk}."
    local cmd_ncatted
    cmd_ncatted="ncatted -O -a history,global,o,c,\"${hist}\" ${OUT_FILE}"
    log "Stamping history attribute ..."
    eval "${cmd_ncatted}" || die "ncatted failed"
    log "History attribute written to ${OUT_FILE}."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log "========================================================"
    log "oisst_concat.sh  |  year=${YEAR}  |  user=$(id -un)"
    log "========================================================"

    check_deps
    [[ -d "${DIR_YEAR}" ]] || die "Source directory does not exist: ${DIR_YEAR}"
    [[ -d "${PATH_OUT}" ]] || die "Output directory does not exist: ${PATH_OUT}"

    rm_prelim "${YEAR}"
    concat_rechunk

    log "========================================================"
    log "Done. Output: ${OUT_FILE}"
    log "========================================================"
}

main "$@"