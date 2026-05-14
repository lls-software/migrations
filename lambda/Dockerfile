# syntax=docker/dockerfile:1.7
#
# Build:  docker buildx build --platform linux/arm64 -f lambda/Dockerfile -t migrations-lambda .
# (run from repo root)

ARG PG_PACKAGE=postgresql18

FROM --platform=linux/arm64 public.ecr.aws/lambda/nodejs:24 AS builder
WORKDIR /build

COPY lambda/package.json lambda/package-lock.json ./
RUN npm ci

COPY lambda/tsconfig.json lambda/handler.ts ./
RUN npx tsc

COPY VERSION build.sh ./
COPY src/ ./src/
RUN ./build.sh


FROM --platform=linux/arm64 public.ecr.aws/lambda/nodejs:24
ARG PG_PACKAGE

RUN dnf install -y "$PG_PACKAGE" \
 && dnf clean all \
 && rm -rf /var/cache/dnf

COPY lambda/package.json lambda/package-lock.json ${LAMBDA_TASK_ROOT}/
RUN cd ${LAMBDA_TASK_ROOT} \
 && npm ci --omit=dev \
 && rm -f package-lock.json

COPY --from=builder /build/dist/handler.js ${LAMBDA_TASK_ROOT}/handler.js
COPY --from=builder /build/migrations.sh ${LAMBDA_TASK_ROOT}/migrations.sh
RUN chmod +x ${LAMBDA_TASK_ROOT}/migrations.sh

ADD https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem ${LAMBDA_TASK_ROOT}/rds-global-bundle.pem
RUN chmod 0444 ${LAMBDA_TASK_ROOT}/rds-global-bundle.pem

CMD ["handler.handler"]
