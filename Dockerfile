FROM rust:1.76.0 as base
RUN git clone --depth=1 --branch=nightly-42a9d349d6f950ffb9d45e2bb9495d4060d68ea7 https://github.com/foundry-rs/foundry.git
RUN cargo install --path ./foundry/crates/forge --profile local --force --locked

FROM base as contracts
WORKDIR /app/contracts/
COPY ./contracts .
RUN forge build

FROM node:18-alpine AS frontend

FROM frontend AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json yarn.lock* ./
RUN yarn --frozen-lockfile

FROM frontend AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
COPY --from=contracts /app/contracts/out ./contracts/out
RUN npx typechain --target=ethers-v6 'contracts/out/**/*.json'
RUN yarn run build

FROM frontend AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

RUN mkdir .next
RUN chown nextjs:nodejs .next


COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]