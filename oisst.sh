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
# oisst_dl.sh
# Download daily OISST AVHRR NetCDF files from ncei.noaa.gov and store them
# in per-year subdirectories. Handles both final and preliminary files,
# and removes superseded preliminary files once a final file arrives.
#
# Usage:
#   ./oisst_dl.sh -y <year> [-st <day> <month>] [-en <day> <month>] [-v]
#
# Examples:
#   ./oisst_dl.sh -y 2023
#   ./oisst_dl.sh -y 2023 -st 1 6 -en 30 9          # June–September only
#   ./oisst_dl.sh -y 2024 -st 1 1                    # 1 Jan to today
#
# Dependencies: wget, date (GNU coreutils)

# Date created:
# 2026-04-21
# Last change:
# 2026-04-21
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
readonly URL_BASE='https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr'
readonly FILE_PREFIX='oisst-avhrr-v02r01.'
readonly FILE_SUFFIX='.nc'
readonly PRELIM_SUFFIX='_preliminary.nc'
readonly PATH_BASE='/g/data/jt48/aus-ref-clim-data-nci/oisst/data/tmp'
readonly LOG_FILE='update_log.txt'

readonly WGET_OPTS=('--no-clobber' '--timeout=60' '--tries=3')

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
# Dependency check
# -----------------------------------------------------------------------------
check_deps() {
    local missing=()
    for cmd in wget date; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"

    # Confirm GNU date (needed for -d arithmetic)
    date --version &>/dev/null || die "GNU date is required (macOS users: brew install coreutils)"
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
YEAR=''
START_DAY=''
START_MONTH=''
END_DAY=''
END_MONTH=''
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--year)
            YEAR="${2:?'--year requires an argument'}"
            shift 2
            ;;
        -st|--start)
            START_DAY="${2:?'-st requires <day> <month>'}"
            START_MONTH="${3:?'-st requires <day> <month>'}"
            shift 3
            ;;
        -en|--end)
            END_DAY="${2:?'-en requires <day> <month>'}"
            END_MONTH="${3:?'-en requires <day> <month>'}"
            shift 3
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

# Validate optional day/month pairs are numeric if supplied
for var_name in START_DAY START_MONTH END_DAY END_MONTH; do
    val="${!var_name}"
    [[ -z "${val}" || "${val}" =~ ^[0-9]+$ ]] || die "${var_name} must be numeric, got: ${val}"
done

# -----------------------------------------------------------------------------
# Resolve the date range
# -----------------------------------------------------------------------------
resolve_dates() {
    local today_year
    today_year="$(date +%Y)"

    if [[ -n "${START_DAY}" && -n "${START_MONTH}" ]]; then
        START_YMD="$(date -d "${YEAR}-${START_MONTH}-${START_DAY}" '+%Y%m%d')" \
            || die "Invalid start date: ${START_DAY}/${START_MONTH}/${YEAR}"
    else
        START_YMD="${YEAR}0101"
    fi

    if [[ -n "${END_DAY}" && -n "${END_MONTH}" ]]; then
        END_YMD="$(date -d "${YEAR}-${END_MONTH}-${END_DAY} +1 day" '+%Y%m%d')" \
            || die "Invalid end date: ${END_DAY}/${END_MONTH}/${YEAR}"
    elif [[ "${YEAR}" -eq "${today_year}" ]]; then
        END_YMD="$(date '+%Y%m%d')"
    else
        END_YMD="$((YEAR + 1))0101"
    fi

    [[ "${START_YMD}" < "${END_YMD}" ]] \
        || die "Start date (${START_YMD}) must be before end date (${END_YMD})"
}

# -----------------------------------------------------------------------------
# Ensure the per-year directory exists
# -----------------------------------------------------------------------------
ensure_dir() {
    local dir="${PATH_BASE}/${YEAR}"
    if [[ ! -d "${dir}" ]]; then
        log "Creating directory: ${dir}"
        mkdir -p "${dir}"
    elif [[ "${VERBOSE}" == true ]]; then
        log "Directory exists: ${dir}"
    fi
}

# -----------------------------------------------------------------------------
# Remove a preliminary file if the final file is already present
# -----------------------------------------------------------------------------
rm_prelim_if_superseded() {
    local date_ymd="$1"
    local dir="${PATH_BASE}/${YEAR}"
    local final_file="${dir}/${FILE_PREFIX}${date_ymd}${FILE_SUFFIX}"
    local prelim_file="${dir}/${FILE_PREFIX}${date_ymd}${PRELIM_SUFFIX}"

    if [[ -f "${final_file}" && -f "${prelim_file}" ]]; then
        [[ "${VERBOSE}" == true ]] && log "  Removing superseded preliminary: ${prelim_file}"
        rm -f "${prelim_file}"
    fi
}

# -----------------------------------------------------------------------------
# Download one day's files (final + preliminary)
# wget -N skips the download if the local file is already up-to-date.
# -----------------------------------------------------------------------------
download_day() {
    local date_ymd="$1"
    local date_ym="${date_ymd:0:6}"

    local dir="${PATH_BASE}/${YEAR}"
    local wget_log="${dir}/wget_output.log"

    local url_final="${URL_BASE}/${date_ym}/${FILE_PREFIX}${date_ymd}${FILE_SUFFIX}"
    local url_prelim="${URL_BASE}/${date_ym}/${FILE_PREFIX}${date_ymd}${PRELIM_SUFFIX}"

    [[ "${VERBOSE}" == true ]] && log "  Fetching: ${url_final}"

    # Download final file; a 404 (no final file yet) is not fatal
    wget "${WGET_OPTS[@]}" \
        -P "${dir}" \
        -a "${wget_log}" \
        "${url_final}" 2>/dev/null || true

    # Download preliminary file; also non-fatal if absent
    #wget "${WGET_OPTS[@]}" \
    #    -P "${dir}" \
    #    -a "${wget_log}" \
    #    "${url_prelim}" 2>/dev/null || true

    # Clean up any preliminary file now superseded by the final
    rm_prelim_if_superseded "${date_ymd}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    check_deps
    resolve_dates
    ensure_dir

    log "========================================================"
    log "oisst_dl.sh  |  year=${YEAR}  |  user=$(id -un)"
    log "Date range  :  ${START_YMD} -> ${END_YMD} (exclusive)"
    log "Output dir  :  ${PATH_BASE}/${YEAR}"
    log "wget log    :  ${PATH_BASE}/${YEAR}/wget_output.log"
    log "========================================================"

    local current="${START_YMD}"
    local count=0

    while [[ "${current}" < "${END_YMD}" ]]; do
        download_day "${current}"
        (( count++ )) || true

        # Advance by one day
        current="$(date -d "${current} +1 day" '+%Y%m%d')"
    done

    log "========================================================"
    log "Done. Downloaded/checked ${count} day(s)."
    log "wget detail log: ${PATH_BASE}/${YEAR}/wget_output.log"
    log "========================================================"
}

main "$@"