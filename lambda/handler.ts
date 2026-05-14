import { spawn } from 'node:child_process'
import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import type { Writable } from 'node:stream'
import { type } from 'arktype'

interface ResponseStream extends Writable {
  setContentType(contentType: string): void
}

declare const awslambda: {
  streamifyResponse: <E = unknown, C = unknown>(
    handler: (event: E, stream: ResponseStream, context: C) => Promise<void>,
  ) => (event: E, context: C) => Promise<void>
}

const MIGRATIONS_SH = process.env.MIGRATIONS_SH ?? '/var/task/migrations.sh'

const filename = /^[0-9]{10}(?:[0-9]{4})?_[A-Za-z0-9_]+\.sql$/
const id = 'string | number | null'

const Setup = type({
  jsonrpc: "'2.0'",
  id,
  method: "'setup'",
  params: { dburl: 'string' },
})

const Status = type({
  jsonrpc: "'2.0'",
  id,
  method: "'status'",
  params: { dburl: 'string' },
})

const Apply = type({
  jsonrpc: "'2.0'",
  id,
  method: "'apply'",
  params: { dburl: 'string', filename, content: 'string' },
})

const Mark = type({
  jsonrpc: "'2.0'",
  id,
  method: "'mark'",
  params: { dburl: 'string', filename, content: 'string' },
})

const Unmark = type({
  jsonrpc: "'2.0'",
  id,
  method: "'unmark'",
  params: { dburl: 'string', filename },
})

const Request = Setup.or(Status).or(Apply).or(Mark).or(Unmark)
type Request = typeof Request.infer

async function withTmpdir<T>(fn: (dir: string) => Promise<T>): Promise<T> {
  const dir = await mkdtemp(join(tmpdir(), 'migrations-'))
  try {
    return await fn(dir)
  } finally {
    await rm(dir, { recursive: true, force: true })
  }
}

async function runMigrations(args: string[], stream: ResponseStream): Promise<void> {
  const child = spawn('stdbuf', ['-oL', MIGRATIONS_SH, ...args], {
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  child.stdout.pipe(stream, { end: false })
  child.stderr.pipe(stream, { end: false })
  const code = await new Promise<number>((resolve, reject) => {
    child.on('error', reject)
    child.on('exit', (c) => resolve(c ?? -1))
  })
  if (code !== 0) {
    throw new Error(`migrations.sh exited with code ${code}`)
  }
}

function tsFromFilename(name: string): string {
  return name.split('_', 1)[0]!
}

async function dispatch(req: Request, stream: ResponseStream): Promise<void> {
  switch (req.method) {
    case 'setup':
      return runMigrations(['setup', req.params.dburl], stream)
    case 'status':
      return withTmpdir((dir) =>
        runMigrations(
          ['status', req.params.dburl, '--dir', dir, '--history', '--porcelain'],
          stream,
        ),
      )
    case 'apply':
      return withTmpdir(async (dir) => {
        await writeFile(join(dir, req.params.filename), req.params.content)
        await runMigrations(['apply', req.params.dburl, '--dir', dir], stream)
      })
    case 'mark':
      return withTmpdir(async (dir) => {
        await writeFile(join(dir, req.params.filename), req.params.content)
        const ts = tsFromFilename(req.params.filename)
        await runMigrations(['mark', req.params.dburl, ts, '--dir', dir], stream)
      })
    case 'unmark': {
      const ts = tsFromFilename(req.params.filename)
      return runMigrations(['unmark', req.params.dburl, ts], stream)
    }
  }
}

export const handler = awslambda.streamifyResponse(
  async (event: unknown, stream: ResponseStream): Promise<void> => {
    stream.setContentType('text/plain; charset=utf-8')
    const parsed = Request(event)
    if (parsed instanceof type.errors) {
      stream.write(`error: invalid request: ${parsed.summary}\n`)
      throw new Error('invalid request')
    }
    await dispatch(parsed, stream)
    stream.end()
  },
)
