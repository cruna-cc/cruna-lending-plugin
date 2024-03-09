# Cruna Plugin Sample

A Cruna Protocol Plugin boilerplate

## Getting Started

1. Clone this repository
2. Install dependencies using pnpm (recommended). If you already use pnpm, skip the first two lines.
```
npm i -g pnpm
pnpm setup
pnpm i
```
3. Compile contracts: `npm run compile`
4. Run tests: `npm test`

## The Badge Collector

This example is a simple, probably not very useful, badge collector contract that allows users to collect badges. The contract emits an event when a badge is collected.
It is also able to (try to) transfer the badge to another user — which will fail if the badge is not transferable.

## Your code

Replace the code with your own plugin contract code and update the tests in test/integration.test.js to match your contract.

## Copyright

(c) 2024 Cruna

## License

MIT
