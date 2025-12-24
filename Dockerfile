# =============================================================================
# Dockerfile Multi-Stage pour Spring PetClinic
# Stage 1: Build avec Maven
# Stage 2: Runtime avec JRE (multi-architecture)
# =============================================================================

# -----------------------------------------------------------------------------
# STAGE 1: BUILD
# -----------------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS builder

LABEL maintainer="DevTech Solutions"
LABEL description="Spring PetClinic Application - Build Stage"

WORKDIR /app

# Copie du pom.xml pour télécharger les dépendances (cache Docker)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copie du code source
COPY src ./src

# Build de l'application (skip tests car déjà exécutés dans le pipeline)
RUN mvn package -DskipTests -B

# -----------------------------------------------------------------------------
# STAGE 2: RUNTIME (multi-arch: amd64, arm64)
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jre

LABEL maintainer="DevTech Solutions"
LABEL description="Spring PetClinic Application - Production"
LABEL version="1.0.0"

# Création d'un utilisateur non-root pour la sécurité
RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

WORKDIR /app

# Copie du JAR depuis le stage de build
COPY --from=builder /app/target/*.jar app.jar

# Changement de propriétaire
RUN chown -R petclinic:petclinic /app

# Utilisation de l'utilisateur non-root
USER petclinic

# Port exposé
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Variables d'environnement JVM optimisées pour conteneur
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# Point d'entrée
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
