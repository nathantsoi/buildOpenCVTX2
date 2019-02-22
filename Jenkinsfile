#!/usr/bin/env groovy

env.CCACHE_DIR = '/jobcache/ccache'

parallel(
    failFast: true,
    "amd64-xenial": { 
        node('docker && amd64') {
            stage("amd64 build pcl"){
                checkout scm
                docker.image('ubuntu:bionic').inside("-u 0:0 -v ${env.WORKSPACE}:/workspace/src") {
                withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'artifactory_apt',
                        usernameVariable: 'ARTIFACTORY_USERNAME', passwordVariable: 'ARTIFACTORY_PASSWORD']]) {
                    withCredentials([string(credentialsId: 'github-access-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                        export ARCH='amd64'
                        export OPENCV_ARCH='x86_64'
                        export DISTRO='xenial'
                        ./buildAndPackageOpenCV.sh 
                        '''
                    } }
                } 
            }
        }},
    
    "arm64-xenial": { 
        node('docker && arm64') {
            stage("arm64 build pcl"){
                checkout scm
                docker.image('arm64v8/ubuntu:bionic').inside("-u 0:0 -v ${env.WORKSPACE}:/workspace/src") {
                withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'artifactory_apt',
                        usernameVariable: 'ARTIFACTORY_USERNAME', passwordVariable: 'ARTIFACTORY_PASSWORD']]) {
                    withCredentials([string(credentialsId: 'github-access-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                        export ARCH='arm64'
                        export OPENCV_ARCH='arm64'
                        export DISTRO='xenial'
                        ./buildAndPackageOpenCV.sh 
                        '''
                    } }
                } 
            }
        }}
)
