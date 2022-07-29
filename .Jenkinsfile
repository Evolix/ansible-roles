pipeline {
    agent { label 'docker' }

    environment {
        ROLES_VERSION = "${env.GIT_COMMIT}"
    }

    stages {
        stage('Build tagged docker image') {
            when {
                buildingTag()
            }
            steps {
                script {
                    def im = docker.build("evolix/ansible-roles:build${env.BUILD_ID}")
                    im.inside {
                        sh 'echo Test needed'
                    }
                    def version = TAG_NAME
                    def versions = version.split('\\.')
                    def major = versions[0]
                    def minor = versions[0] + '.' + versions[1]
                    def patch = version.trim()
                    docker.withRegistry('', 'hub.docker') {
                        im.push(major)
                        im.push(minor)
                        im.push(patch)
                    }
                }
            }
        }

        stage('Build latest docker image') {
            when {
                branch 'unstable'
            }
            steps {
                script {
                    def im = docker.build("evolix/ansible-roles:build${env.BUILD_ID}")
                    im.inside {
                        sh 'echo Test needed'
                    }
                    docker.withRegistry('', 'hub.docker') {
                        im.push('latest')
                    }
                }
            }
        }
    }
}
