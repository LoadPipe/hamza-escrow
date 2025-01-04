
## Deployed Contracts

### Optimism Mainnet

- Escrow: https://optimistic.etherscan.io/address/0x585795466CCb929Ed2B556C9Cf393A2778c0df06
- SecurityContext: https://optimistic.etherscan.io/address/0x9857FC6111ED98509cb559897B484319acDAc4D4
- SystemSettings: https://optimistic.etherscan.io/address/0xC063bc8594Fc6F2CB120cB1f924D15b964afd4D1
- Multicall: https://optimistic.etherscan.io/address/0xdFc33612146333D809eD1a4ee7A79B9C776B86b4


### Polygon Amoy

- Escrow: 0xEb6b6144B0DDC6494FB7483D209ecc41A7Ae2Cc5
- SecurityContext: 0x9857FC6111ED98509cb559897B484319acDAc4D4
- SystemSettings: 0x0A453Ac4587C52e33A92085bE17BE0B1EE374534
- Multicall: 0xa8866FF28D26cdf312e5C902e8BFDbCf663a36ce

### Sepolia 

- Escrow: 0xAb6a9e96E08d0ec6100016a308828B792f4da3fD
- SecurityContext: 0x4d10Beb61799Ad13022B178d276b34490719aD01
- SystemSettings: 0x48D7096A4a09AdE9891E5753506DF2559EAFdad3
- Multicall: 0xeE54D440927b94015325D79CD7CB51A5212d99a9


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

