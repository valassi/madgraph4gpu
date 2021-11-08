#!/bin/bash

#--------------------------------------------------------------------------------------

function codeGenAndDiff()
{
  proc=$1
  # Process-dependent hardcoded configuration
  echo -e "\n================================================================"
  case "${proc}" in
    ee_mumu)
      cmd="generate e+ e- > mu+ mu-"
      ;;
    gg_tt)
      cmd="generate g g > t t~"
      ;;
    gg_ttg)
      cmd="generate g g > t t~ g"
      ;;
    gg_ttgg)
      cmd="generate g g > t t~ g g"
      ;;
    *)
      echo -e "\nWARNING! Skipping unknown process '$proc'"
      return
      ;;
  esac
  echo -e "\n+++ Generate code for '$proc'\n"
  ###exit 0 # FOR DEBUGGING
  # Generate code for the specific process
  pushd $MG5AMC_HOME >& /dev/null
  outproc=CODEGEN_${proc}
  \rm -rf ${outproc}*
  ###echo "set stdout_level DEBUG" >> ${outproc}.mg # does not help (log is essentially identical)
  echo "${cmd}" >> ${outproc}.mg
  echo "output standalone_${OUTBCK} ${outproc}" >> ${outproc}.mg
  cat  ${outproc}.mg
  ###{ strace -f -o ${outproc}_strace.txt python3 ./bin/mg5_aMC ${outproc}.mg ; } >& ${outproc}_log.txt
  { time python3 ./bin/mg5_aMC ${outproc}.mg ; } >& ${outproc}_log.txt
  if [ -d ${outproc} ] && ! grep -q "Please report this bug" ${outproc}_log.txt; then
    ###cat ${outproc}_log.txt; exit 0 # FOR DEBUGGING
    cat ${outproc}_log.txt | egrep 'INFO: (Try|Creat|Organiz|Process)'
    mv ${outproc}_log.txt ${outproc}/
  else
    echo "*** ERROR! Code generation failed"
    cat ${outproc}_log.txt
    echo "*** ERROR! Code generation failed"
    exit 1
  fi
  popd >& /dev/null
  # Move the newly generated code to the output source code directory
  rm -rf ${OUTDIR}/${proc}.auto.BKP ${OUTDIR}/${proc}.auto.NEW
  cp -dpr ${MG5AMC_HOME}/${outproc} ${OUTDIR}/${proc}.auto.NEW
  echo -e "\nOutput source code has been copied to ${OUTDIR}/${proc}.auto.NEW"
  # Compare the newly generated code to the existing generated code for the specific process
  pushd ${OUTDIR} >& /dev/null
  echo -e "\n+++ Compare new and old code generation log for $proc\n"
  ###diff -c ${proc}.auto.NEW/${outproc}_log.txt ${proc}.auto # context diff
  diff ${proc}.auto.NEW/${outproc}_log.txt ${proc}.auto # normal diff
  echo -e "\n+++ Compare new and old generated code for $proc\n"
  if diff ${BRIEF} --no-dereference -x '*log.txt' -x 'nsight_logs' -x '*.o' -x '*.o.*' -x '*.a' -x '*.exe' -x 'lib' -x 'build.*' -x '.build.*' -x '*~' -r -c ${proc}.auto.NEW ${proc}.auto; then echo "New and old generated codes are identical"; else echo -e "\nWARNING! New and old generated codes differ"; fi
  popd >& /dev/null
  # Compare the newly generated code to the existing manually developed code for the specific process
  pushd ${OUTDIR} >& /dev/null
  echo -e "\n+++ Compare newly generated code to manually developed code for $proc\n"
  if diff ${BRIEF} --no-dereference -x '*log.txt' -x 'nsight_logs' -x '*.o' -x '*.o.*' -x '*.a' -x '*.exe' -x 'lib' -x 'build.*' -x '.build.*' -x '*~' -r -c ${proc}.auto.NEW ${proc}; then echo "Generated and manual codes are identical"; else echo -e "\nWARNING! Generated and manual codes differ"; fi
  # Replace the existing generated code by the newly generated code if required
  if [ "${REPLACE}" == "1" ]; then
    echo -e "\n+++ Replace existing generated code for $proc (REPLACE=$REPLACE)\n"
    mv ${OUTDIR}/${proc}.auto ${OUTDIR}/${proc}.auto.BKP
    mv ${OUTDIR}/${proc}.auto.NEW ${OUTDIR}/${proc}.auto
    echo -e "Manually developed code is\n  ${OUTDIR}/${proc}"
    echo -e "Old generated code moved to\n  ${OUTDIR}/${proc}.auto.BKP"
    echo -e "New generated code moved to\n  ${OUTDIR}/${proc}.auto"
  else
    echo -e "\n+++ Keep existing generated code for $proc (REPLACE=$REPLACE)\n"
    echo -e "Manually developed code is\n  ${OUTDIR}/${proc}"
    echo -e "Old generated code is\n  ${OUTDIR}/${proc}.auto"
    echo -e "New generated code is\n  ${OUTDIR}/${proc}.auto.NEW"
  fi
}

#--------------------------------------------------------------------------------------

function usage()
{
  echo "Usage: $0 [--replace|--noreplace] [--brief] [<proc1> [... <procN>]]"
  exit 1
}

#--------------------------------------------------------------------------------------

# Replace code directory and create .BKP? (or alternatively keep code directory in .NEW?)
REPLACE=0

# Brief diffs?
BRIEF=

# Process command line arguments (https://unix.stackexchange.com/a/258514)
for arg in "$@"; do
  shift
  if [ "$arg" == "-h" ] || [ "$arg" == "--help" ]; then
    usage; continue; # continue is unnecessary as usage will exit anyway...
  elif [ "$arg" == "--replace" ]; then
    REPLACE=1; continue;
  elif [ "$arg" == "--noreplace" ]; then
    REPLACE=0; continue;
  elif [ "$arg" == "--brief" ]; then
    BRIEF=--brief; continue
  else
    set -- "$@" "$arg"
  fi
done
procs=$@
echo REPLACE=${REPLACE}
echo BRIEF=${BRIEF}
echo procs=${procs}

# Script directory
SCRDIR=$(cd $(dirname $0); pwd)
echo SCRDIR=${SCRDIR}

# Output source code directory for the chosen backend
OUTDIR=$(dirname $SCRDIR) # e.g. epochX/cudacpp if $SCRDIR=epochX/cudacpp/CODEGEN
echo OUTDIR=${OUTDIR}

# Output backend
OUTBCK=$(basename $OUTDIR) # e.g. cudacpp if $OUTDIR=epochX/cudacpp
echo "OUTBCK=${OUTBCK} (uppercase=${OUTBCK^^})"

# Make sure that python3 is installed
if ! python3 --version >& /dev/null; then echo "ERROR! python3 is not installed"; exit 1; fi

# Make sure that $MG5AMC_HOME exists
if [ "$MG5AMC_HOME" == "" ]; then
  echo "ERROR! MG5AMC_HOME is not defined"
  echo "To download MG5AMC please run 'bzr branch lp:~maddevelopers/mg5amcnlo/2.7.0_gpu'"
  exit 1
fi
echo -e "\nUsing MG5AMC_HOME=$MG5AMC_HOME on $(hostname)\n"
if [ ! -d $MG5AMC_HOME ]; then echo "ERROR! Directory $MG5AMC_HOME does not exist"; exit 1; fi

# Print MG5amc bazaar info if any
if bzr --version >& /dev/null; then
  echo -e "Using $(bzr --version | head -1)"
  echo -e "Retrieving bzr information about MG5AMC_HOME"
  if bzr info ${MG5AMC_HOME} 2> /dev/null | grep parent; then
    revno_mg5amc=$(bzr revno ${MG5AMC_HOME})
    echo -e "Current bzr revno of MG5AMC_HOME is '${revno_mg5amc}'"
    revno_patches=$(cat $SCRDIR/MG5aMC_patches/2.7.0_gpu/revision.BZR)
    echo -e "Revert MG5AMC_HOME to current bzr revno"
    bzr revert ${MG5AMC_HOME}
    echo -e "MG5AMC patches in this plugin refer to bzr revno '${revno_patches}'"
    if [ "${revno_patches}" != "${revno_mg5amc}" ]; then echo -e "\nERROR! bzr revno mismatch!"; exit 1; fi
  else
    echo -e "WARNING! MG5AMC_HOME is not a bzr branch\n"
  fi
else
  echo -e "WARNING! bzr is not installed: cannot retrieve bzr properties of MG5aMC_HOME\n"
fi

# Copy MG5AMC patches if any
patches=$(cd $SCRDIR/MG5aMC_patches/2.7.0_gpu; find . -type f -name '*.py')
echo -e "Copy MG5aMC_patches/2.7.0_gpu patches..."
for patch in $patches; do
  patch=${patch#./}
  echo cp -dpr $SCRDIR/MG5aMC_patches/2.7.0_gpu/$patch $MG5AMC_HOME/$patch
  cp -dpr $SCRDIR/MG5aMC_patches/2.7.0_gpu/$patch $MG5AMC_HOME/$patch
done
echo -e "Copy MG5aMC_patches/2.7.0_gpu patches... done\n"

# Remove and recreate MG5AMC_HOME/PLUGIN, remove MG5aMC fragments from previous runs
rm -rf ${MG5AMC_HOME}/py.py
rm -rf ${MG5AMC_HOME}/PLUGIN
mkdir ${MG5AMC_HOME}/PLUGIN
touch ${MG5AMC_HOME}/PLUGIN/__init__.py

# Print MG5amc bazaar info if any
if bzr --version >& /dev/null; then
  if bzr info ${MG5AMC_HOME} 2> /dev/null | grep parent; then
    echo -e "\n***************** Differences to the current bzr revno [START]"
    if bzr diff ${MG5AMC_HOME}; then echo -e "[No differences]"; fi
    echo -e "***************** Differences to the current bzr revno [END]\n"
  fi
fi

# Copy the new plugin to MG5AMC_HOME
cp -dpr ${SCRDIR}/PLUGIN/${OUTBCK^^}_SA_OUTPUT ${MG5AMC_HOME}/PLUGIN/
ls -l ${MG5AMC_HOME}/PLUGIN
###ls -lR ${MG5AMC_HOME}/PLUGIN

# Determine the list of processes to generate
###procs="ee_mumu gg_tt gg_ttg gg_ttgg"
if [ "$procs" == "" ] ; then procs=$(cd $OUTDIR; find . -mindepth 1 -maxdepth 1 -type d -name '*.auto' | sed 's/.auto//'); fi

# Iterate through the list of processes to generate
for proc in $procs; do
  if [ -d $OUTDIR/$proc ]; then proc=$(basename $proc); fi
  codeGenAndDiff $proc
done
