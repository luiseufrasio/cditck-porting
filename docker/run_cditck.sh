#!/bin/bash -x -e
#
# Copyright (c) 2018, 2020 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2019, 2020 Payara Foundation and/or its affiliates. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v. 2.0, which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# This Source Code may also be made available under the following Secondary
# Licenses when the conditions for such availability set forth in the
# Eclipse Public License v. 2.0 are satisfied: GNU General Public License,
# version 2 with the GNU Classpath Exception, which is available at
# https://www.gnu.org/software/classpath/license.html.
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0

VER="3.0.1"
if ls ${WORKSPACE}/bundles/*cdi-tck*.zip 1> /dev/null 2>&1; then
  unzip -o ${WORKSPACE}/bundles/*cdi-tck*.zip -d ${WORKSPACE}
else
  echo "[ERROR] TCK bundle not found"
  exit 1
fi

export TS_HOME=${WORKSPACE}/cdi-tck-glassfish-porting

#Install Glassfish
echo "Download and install GlassFish ..."
wget --progress=bar:force --no-cache $GF_BUNDLE_URL -O ${WORKSPACE}/latest-glassfish.zip
unzip -o ${WORKSPACE}/latest-glassfish.zip -d ${WORKSPACE}


which ant
ant -version

REPORT=${WORKSPACE}/cdi-tck-report

mkdir -p ${REPORT}/cdi-$VER-sig
mkdir -p ${REPORT}/cdi-$VER

#Edit Glassfish Security policy
cat ${WORKSPACE}/docker/CDI.policy >> ${WORKSPACE}/payara5/glassfish/domains/domain1/config/server.policy

#Edit test properties
sed -i "s#porting.home=.*#porting.home=${TS_HOME}#g" ${TS_HOME}/build.properties
sed -i "s#glassfish.home=.*#glassfish.home=${WORKSPACE}/payara5/glassfish#g" ${TS_HOME}/build.properties
if [[ "${PROFILE}" == "web" || "${PROFILE}" == "WEB" ]]; then
  sed -i "s#javaee.level=.*#javaee.level=web#g" ${TS_HOME}/build.properties
else
  sed -i "s#javaee.level=.*#javaee.level=full#g" ${TS_HOME}/build.properties
fi
sed -i "s#report.dir=.*#report.dir=${REPORT}#g" ${TS_HOME}/build.properties
sed -i "s#admin.user=.*#admin.user=admin#g" ${TS_HOME}/build.properties
sed -i "s#cdiextjar=.*#cdiextjar=cdi-tck-ext-lib-${CDI_TCK_VERSION}.jar#g" ${TS_HOME}/build.properties
sed -i "s#cdiext.version=.*#cdiext.version=${CDI_TCK_VERSION}#g" ${TS_HOME}/build.properties

cp ${TS_HOME}/glassfish-tck-runner/src/test/tck20/tck-tests.xml ${TS_HOME}/glassfish-tck-runner/src/test/tck20/tck-tests_bkup.xml 
cp ${DIST}/${CDI_TCK_DIST}/artifacts/cdi-tck-impl-${CDI_TCK_VERSION}-suite.xml ${TS_HOME}/glassfish-tck-runner/src/test/tck20/tck-tests.xml

sed -i "s#<suite name=.*#<suite name=\"CDI TCK\" verbose=\"0\" configfailurepolicy=\"continue\">#g" ${TS_HOME}/glassfish-tck-runner/src/test/tck20/tck-tests.xml

#Run Tests
cd ${TS_HOME}
export MAVEN_OPTS="-Duser.home=$HOME $MAVEN_OPTS"
ant -Duser.home=$HOME sigtest
ant -Duser.home=$HOME test


#Generate Reports
echo "<pre>" > ${REPORT}/cdi-$VER-sig/report.html
cat $REPORT/cdi_sig_test_results.txt >> $REPORT/cdi-$VER-sig/report.html
echo "</pre>" >> $REPORT/cdi-$VER-sig/report.html
cp $REPORT/cdi-$VER-sig/report.html $REPORT/cdi-$VER-sig/index.html

# Copy the test reports to the report directory
cp -R ${TS_HOME}/glassfish-tck-runner/target/surefire-reports/* ${REPORT}/cdi-${VER}
if [[ -f ${REPORT}/cdi-$VER/test-report.html ]];then
  cp ${REPORT}/cdi-$VER/test-report.html ${REPORT}/cdi-${VER}/report.html
fi

mv ${REPORT}/cdi-$VER/TEST-TestSuite.xml  ${REPORT}/cdi-$VER/cditck-$VER-junit-report.xml
sed -i 's/name=\"TestSuite\"/name="cditck-3.0"/g' ${REPORT}/cdi-$VER/cditck-$VER-junit-report.xml

# Create Junit formated file for sigtests
echo '<?xml version="1.0" encoding="UTF-8" ?>' > $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
echo '<testsuite tests="TOTAL" failures="FAILED" name="cdi-3.0.1-sig" time="0" errors="0" skipped="0">' >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
echo '<testcase classname="CDISigTest" name="cdiSigTest" time="0.2">' >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
echo '  <system-out>' >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
cat $REPORT/cdi_sig_test_results.txt >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
echo '  </system-out>' >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
echo '</testcase>' >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml
echo '</testsuite>' >> $REPORT/cdi-$VER-sig/cdi-$VER-sig-junit-report.xml

tar zcvf ${WORKSPACE}/cdi-tck-results.tar.gz ${REPORT} ${WORK}
