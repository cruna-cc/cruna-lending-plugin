# Cruna Lending Plugin
This plugin allows projects to lend assets to owners of a vault that have plugged in the plugin.

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

## The Cruna Lending Plugin
As well as the plugin contracts there is a contract called LendingRules.sol where the rules for lending are defined.

You will need to update the LendingRules.sol contract to match your lending rules.

## Copyright

(c) 2024 Cruna

## License

GPL-3.0
```
