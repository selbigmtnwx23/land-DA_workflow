#!/bin/sh

set -xue

echo '************************************************'
echo 'running the forecast model' 

case $MACHINE in
  "hera")
    RUN_CMD="srun"
    ;;
  "orion")
    RUN_CMD="srun"
    ;;
  "hercules")
    RUN_CMD="srun"
    ;;
  *)
    RUN_CMD=`which mpiexec`
    ;;
esac

export MPI_TYPE_DEPTH=20
export OMP_STACKSIZE=512M
# shellcheck disable=SC2125
export OMP_NUM_THREADS=1
export ESMF_RUNTIME_COMPLIANCECHECK=OFF:depth=4
export ESMF_RUNTIME_PROFILE=ON
export ESMF_RUNTIME_PROFILE_OUTPUT="SUMMARY"
export PSM_RANKS_PER_CONTEXT=4
export PSM_SHAREDCONTEXTS=1

YYYY=${PDY:0:4}
MM=${PDY:4:2}
DD=${PDY:6:2}
HH=${cyc}
YYYYMMDD=${PDY}
nYYYY=${NTIME:0:4}
nMM=${NTIME:4:2}
nDD=${NTIME:6:2}
nHH=${NTIME:8:2}

FILEDATE=${YYYY}${MM}${DD}.${HH}0000

# Copy input namelist data files
cp -p ${PARMlandda}/templates/template.input.nml input.nml
cp -p ${PARMlandda}/templates/template.datm_in datm_in
cp -p ${PARMlandda}/templates/template.datm.streams datm.streams
cp -p ${PARMlandda}/templates/template.noahmptable.tbl noahmptable.tbl
cp -p ${PARMlandda}/templates/template.fd_ufs.yaml fd_ufs.yaml
cp -p ${PARMlandda}/templates/template.data_table data_table

# Set ufs.configure
cp -p ${PARMlandda}/templates/template.ufs.configure ufs.configure
nprocs_atm_m1=$(( NPROCS_FORECAST_ATM - 1 ))
sed -i -e "s/XXNPROCS_ATM_M1/${nprocs_atm_m1}/g" ufs.configure
sed -i -e "s/XXNPROCS_FORECAST_ATM/${NPROCS_FORECAST_ATM}/g" ufs.configure
nprocs_atm_lnd_m1=$(( NPROCS_FORECAST_ATM + NPROCS_FORECAST_LND - 1 ))
sed -i -e "s/XXNPROCS_ATM_LND_M1/${nprocs_atm_lnd_m1}/g" ufs.configure
sed -i -e "s/XXLND_LAYOUT_X/${LND_LAYOUT_X}/g" ufs.configure
sed -i -e "s/XXLND_LAYOUT_Y/${LND_LAYOUT_Y}/g" ufs.configure
sed -i -e "s/XXLND_OUTPUT_FREQ_SEC/${LND_OUTPUT_FREQ_SEC}/g" ufs.configure
sed -i -e "s/XXDT_RUNSEQ/${DT_RUNSEQ}/g" ufs.configure

# Set model_configure
cp -p ${PARMlandda}/templates/template.model_configure model_configure
sed -i -e "s/XXYYYY/${YYYY}/g" model_configure
sed -i -e "s/XXMM/${MM}/g" model_configure
sed -i -e "s/XXDD/${DD}/g" model_configure
sed -i -e "s/XXHH/${HH}/g" model_configure
sed -i -e "s/XXFCSTHR/${FCSTHR}/g" model_configure
sed -i -e "s/XXDT_ATMOS/${DT_ATMOS}/g" model_configure

# set diag table
cp -p ${PARMlandda}/templates/template.diag_table diag_table
sed -i -e "s/XXYYYYMMDD/${YYYYMMDD}/g" diag_table
sed -i -e "s/XXYYYY/${YYYY}/g" diag_table
sed -i -e "s/XXMM/${MM}/g" diag_table
sed -i -e "s/XXDD/${DD}/g" diag_table
sed -i -e "s/XXHH/${HH}/g" diag_table

# Set up the run directory
mkdir -p RESTART

# NoahMP restart files
for itile in {1..6}
do
  ln -nsf ${COMIN}/ufs_land_restart.anal.${YYYY}-${MM}-${DD}_${HH}-00-00.tile${itile}.nc RESTART/ufs.cpld.lnd.out.${YYYY}-${MM}-${DD}-00000.tile${itile}.nc
done

# CMEPS restart and pointer files
rfile1="ufs.cpld.cpl.r.${YYYY}-${MM}-${DD}-00000.nc"
if [[ -e "${COMINm1}/${rfile1}" ]]; then
  ln -nsf "${COMINm1}/${rfile1}" RESTART/.
elif [[ -e "${WARMSTART_DIR}/${rfile1}" ]]; then
  ln -nsf "${WARMSTART_DIR}/${rfile1}" RESTART/.
else
  ln -nsf ${FIXlandda}/restarts/${ATMOS_FORC}/${rfile1} RESTART/.
fi
ls -1 "RESTART/${rfile1}">rpointer.cpl

# CDEPS restart and pointer files
rfile2="ufs.cpld.datm.r.${YYYY}-${MM}-${DD}-00000.nc"
if [[ -e "${COMINm1}/${rfile2}" ]]; then
  ln -nsf "${COMINm1}/${rfile2}" RESTART/.
elif [[ -e "${WARMSTART_DIR}/${rfile2}" ]]; then
  ln -nsf "${WARMSTART_DIR}/${rfile2}" RESTART/.
else
  ln -nsf ${FIXlandda}/restarts/${ATMOS_FORC}/${rfile2} RESTART/.
fi
ls -1 "RESTART/${rfile2}">rpointer.atm

mkdir -p INPUT
cd INPUT
ln -nsf ${FIXlandda}/DATM_input_data/${ATMOS_FORC}/* .
for itile in {1..6}
do
  ln -nsf ${FIXlandda}/NOAHMP_IC/ufs-land_C${RES}_init_fields.tile${itile}.nc C${RES}.initial.tile${itile}.nc
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.maximum_snow_albedo.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.slope_type.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.soil_type.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.soil_color.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.substrate_temperature.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.vegetation_greenness.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}.vegetation_type.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/oro_C${RES}.mx100.tile${itile}.nc oro_data.tile${itile}.nc
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/C${RES}_grid.tile${itile}.nc .
  ln -nsf ${FIXlandda}/FV3_fix_tiled/C${RES}/grid_spec.nc C${RES}_mosaic.nc
done
cd -

# start runs
echo "Start ufs-cdeps-land model run with TASKS: ${NPROCS_FORECAST}"
export pgm="ufs_model"
. prep_step
${RUN_CMD} -n ${NPROCS_FORECAST} ${EXEClandda}/$pgm >>$pgmout 2>errfile
export err=$?; err_chk
cp errfile errfile_ufs_model
if [[ $err != 0 ]]; then
  echo "ufs_model failed"
  exit 10
fi

# copy model ouput to COM
for itile in {1..6}
do
  cp -p ${DATA}/ufs.cpld.lnd.out.${nYYYY}-${nMM}-${nDD}-00000.tile${itile}.nc ${COMOUT}/ufs_land_restart.${nYYYY}-${nMM}-${nDD}_${nHH}-00-00.tile${itile}.nc
done
cp -p ${DATA}/ufs.cpld.datm.r.${nYYYY}-${nMM}-${nDD}-00000.nc ${COMOUT}
cp -p ${DATA}/RESTART/ufs.cpld.cpl.r.${nYYYY}-${nMM}-${nDD}-00000.nc ${COMOUT}

# link restart for next cycle
for itile in {1..6}
do
  ln -nsf ${COMOUT}/ufs_land_restart.${nYYYY}-${nMM}-${nDD}_${nHH}-00-00.tile${itile}.nc ${DATA_RESTART}
done

# WE2E V&V
if [[ "${WE2E_VAV}" == "YES" ]]; then
  path_fbase="${FIXlandda}/test_base/we2e_com/${RUN}.${PDY}"
  fn_res="ufs_land_restart.${nYYYY}-${nMM}-${nDD}_${nHH}-00-00.tile"
  we2e_log_fp="${LOGDIR}/${WE2E_LOG_FN}"
  
  if [[ ! -e "${we2e_log_fp}" ]]; then
    touch ${we2e_log_fp}
  fi
  # restart files
  for itile in {1..6}
  do
    ${USHlandda}/compare.py "${path_fbase}/${fn_res}${itile}.nc" "${COMOUT}/${fn_res}${itile}.nc" ${WE2E_ATOL} ${we2e_log_fp} "FORECAST" ${FILEDATE} "ufs_land_restart.tile${itile}"
  done
fi

