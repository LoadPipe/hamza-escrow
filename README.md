## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Deployed Contracts

Escrow: https://optimistic.etherscan.io/address/0x585795466CCb929Ed2B556C9Cf393A2778c0df06

SecurityContext: https://optimistic.etherscan.io/address/0x9857FC6111ED98509cb559897B484319acDAc4D4

SystemSettings: https://optimistic.etherscan.io/address/0xC063bc8594Fc6F2CB120cB1f924D15b964afd4D1

Multicall: https://optimistic.etherscan.io/address/0xdFc33612146333D809eD1a4ee7A79B9C776B86b4
