// =============================================================================
// Pipeline CI/CD Complet - Spring PetClinic
// Mini-Projet DevOps - ISIL3
// =============================================================================

pipeline {
    agent any

    // -------------------------------------------------------------------------
    // VARIABLES D'ENVIRONNEMENT
    // -------------------------------------------------------------------------
    environment {
        // Docker
        DOCKER_IMAGE = 'rmed19/springpetclinic'
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')

        // SonarQube
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_PROJECT_KEY = 'springpetclinic'

        // Selenium
        SELENIUM_HUB_URL = 'http://selenium-hub:4444/wd/hub'

        // Application
        APP_URL = 'http://petclinic-app:8080'

        // Maven
        MAVEN_OPTS = '-Dmaven.repo.local=.m2/repository'
    }

    // -------------------------------------------------------------------------
    // OPTIONS DU PIPELINE
    // -------------------------------------------------------------------------
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // -------------------------------------------------------------------------
    // DÉCLENCHEURS - GitHub Webhook
    // -------------------------------------------------------------------------
    triggers {
        githubPush()
    }

    // -------------------------------------------------------------------------
    // OUTILS
    // -------------------------------------------------------------------------
    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }

    // -------------------------------------------------------------------------
    // STAGES DU PIPELINE
    // -------------------------------------------------------------------------
    stages {

        // =====================================================================
        // ÉTAPE 1: CHECKOUT - Récupération du code source
        // =====================================================================
        stage('1. Checkout') {
            steps {
                echo '=== ÉTAPE 1: Checkout du code source depuis GitHub ==='

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    extensions: [
                        [$class: 'CleanBeforeCheckout'],
                        [$class: 'CloneOption', depth: 1, shallow: true]
                    ],
                    userRemoteConfigs: [[
                        url: 'https://github.com/rmed19/spring-petclinic.git'
                    ]]
                ])

                sh 'echo "Commit: $(git rev-parse HEAD)"'
                sh 'echo "Branch: $(git branch --show-current)"'
            }
        }

        // =====================================================================
        // ÉTAPE 2: BUILD ET TESTS UNITAIRES
        // =====================================================================
        stage('2. Build & Unit Tests') {
            steps {
                echo '=== ÉTAPE 2: Compilation et Tests Unitaires ==='

                sh '''
                    mvn clean compile -B
                    mvn test -B
                '''
            }
            post {
                always {
                    // Publication des résultats des tests
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
                }
                success {
                    echo 'Build et tests unitaires réussis!'
                }
                failure {
                    echo 'Échec du build ou des tests unitaires!'
                }
            }
        }

        // =====================================================================
        // ÉTAPE 3: ANALYSE SONARQUBE
        // =====================================================================
        stage('3. SonarQube Analysis') {
            steps {
                echo '=== ÉTAPE 3: Analyse de qualité SonarQube ==='

                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        mvn sonar:sonar \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName="Spring PetClinic" \
                            -Dsonar.host.url=${SONAR_HOST_URL} \
                            -Dsonar.java.binaries=target/classes \
                            -B
                    '''
                }
            }
            post {
                success {
                    echo 'Analyse SonarQube terminée!'
                    echo "Voir le rapport: ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
                }
            }
        }

        // =====================================================================
        // ÉTAPE 4: TESTS SELENIUM / TESTNG
        // =====================================================================
        stage('4. Selenium UI Tests') {
            steps {
                echo '=== ÉTAPE 4: Tests UI avec Selenium/TestNG ==='

                // Démarrer l'application temporairement pour les tests
                sh '''
                    mvn package -DskipTests -B

                    # Lancer l'application en arrière-plan
                    java -jar target/*.jar --server.port=9090 &
                    APP_PID=$!

                    # Attendre que l'application démarre
                    echo "Attente du démarrage de l'application..."
                    sleep 30

                    # Vérifier que l'app est up
                    curl -s --retry 10 --retry-delay 5 http://localhost:9090/actuator/health || true

                    # Exécuter les tests Selenium
                    mvn test -Dtest=*SeleniumTest* -Dselenium.hub.url=${SELENIUM_HUB_URL} -Dapp.url=http://host.docker.internal:9090 -B || true

                    # Arrêter l'application
                    kill $APP_PID || true
                '''
            }
            post {
                always {
                    // Publication des rapports TestNG
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/surefire-reports',
                        reportFiles: 'index.html',
                        reportName: 'Selenium Test Report'
                    ])
                }
            }
        }

        // =====================================================================
        // ÉTAPE 5: BUILD IMAGE DOCKER
        // =====================================================================
        stage('5. Docker Build') {
            steps {
                echo '=== ÉTAPE 5: Construction de l\'image Docker ==='

                sh '''
                    # Build du package si pas déjà fait
                    mvn package -DskipTests -B

                    # Construction de l'image Docker
                    docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest

                    # Afficher les images créées
                    docker images | grep ${DOCKER_IMAGE}
                '''
            }
            post {
                success {
                    echo "Image Docker créée: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }

        // =====================================================================
        // ÉTAPE 6: PUSH VERS DOCKER HUB
        // =====================================================================
        stage('6. Push to Docker Hub') {
            steps {
                echo '=== ÉTAPE 6: Push de l\'image vers Docker Hub ==='

                sh '''
                    # Login Docker Hub
                    echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin

                    # Push des images
                    docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                    docker push ${DOCKER_IMAGE}:latest

                    # Logout
                    docker logout
                '''
            }
            post {
                success {
                    echo "Image pushée sur Docker Hub: ${DOCKER_IMAGE}:latest"
                }
            }
        }

        // =====================================================================
        // ÉTAPE 7: DÉPLOIEMENT KUBERNETES (MINIKUBE)
        // =====================================================================
        stage('7. Deploy to Kubernetes') {
            steps {
                echo '=== ÉTAPE 7: Déploiement sur Kubernetes (Minikube) ==='

                sh '''
                    # Vérifier la connexion à Kubernetes
                    kubectl cluster-info || echo "Attention: Cluster K8s non accessible"

                    # Mettre à jour le tag de l'image dans le deployment
                    sed -i "s|IMAGE_TAG|${DOCKER_IMAGE}:${DOCKER_TAG}|g" k8s/deployment.yaml

                    # Appliquer les manifests Kubernetes
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml

                    # Attendre que le déploiement soit prêt
                    kubectl rollout status deployment/petclinic-deployment --timeout=120s

                    # Afficher l'état du déploiement
                    kubectl get deployments
                    kubectl get pods
                    kubectl get services

                    # Afficher l'URL d'accès
                    echo "Application accessible sur: http://$(minikube ip):30080"
                '''
            }
            post {
                success {
                    echo 'Déploiement Kubernetes réussi!'
                }
                failure {
                    echo 'Échec du déploiement Kubernetes!'
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // POST-ACTIONS
    // -------------------------------------------------------------------------
    post {
        // =====================================================================
        // ÉTAPE 8: NOTIFICATION EMAIL EN CAS D'ÉCHEC
        // =====================================================================
        failure {
            echo '=== ÉTAPE 8: Envoi de notification d\'échec ==='

            emailext(
                subject: "ÉCHEC Pipeline: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                body: """
                    <html>
                    <body>
                        <h2 style="color: red;">Pipeline CI/CD en ÉCHEC</h2>

                        <h3>Détails du Job:</h3>
                        <table border="1" cellpadding="5">
                            <tr><td><b>Job</b></td><td>${env.JOB_NAME}</td></tr>
                            <tr><td><b>Build Number</b></td><td>#${env.BUILD_NUMBER}</td></tr>
                            <tr><td><b>Status</b></td><td style="color: red;">FAILURE</td></tr>
                            <tr><td><b>URL</b></td><td><a href="${env.BUILD_URL}">${env.BUILD_URL}</a></td></tr>
                            <tr><td><b>Durée</b></td><td>${currentBuild.durationString}</td></tr>
                        </table>

                        <h3>Cause de l'échec:</h3>
                        <p>Consultez les logs complets: <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>

                        <h3>Derniers commits:</h3>
                        <pre>${currentBuild.changeSets.collect { cs -> cs.items.collect { it.msg }.join('\n') }.join('\n')}</pre>

                        <hr>
                        <p><i>Ce message a été généré automatiquement par Jenkins.</i></p>
                    </body>
                    </html>
                """,
                to: 'equipe-devops@devtech-solutions.com',
                from: 'jenkins@devtech-solutions.com',
                replyTo: 'noreply@devtech-solutions.com',
                mimeType: 'text/html',
                attachLog: true,
                compressLog: true
            )
        }

        success {
            echo '=== Pipeline terminé avec SUCCÈS ==='
            echo "Application déployée et accessible!"
        }

        always {
            // Nettoyage de l'espace de travail
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: 'target/**', type: 'INCLUDE'],
                    [pattern: '.m2/**', type: 'EXCLUDE']
                ]
            )

            // Nettoyage des images Docker non utilisées
            sh 'docker system prune -f || true'
        }
    }
}
