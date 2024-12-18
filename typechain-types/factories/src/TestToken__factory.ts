/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Contract,
  ContractFactory,
  ContractTransactionResponse,
  Interface,
} from "ethers";
import type { Signer, ContractDeployTransaction, ContractRunner } from "ethers";
import type { NonPayableOverrides } from "../../common";
import type { TestToken, TestTokenInterface } from "../../src/TestToken";

const _abi = [
  {
    inputs: [
      {
        internalType: "string",
        name: "name_",
        type: "string",
      },
      {
        internalType: "string",
        name: "symbol_",
        type: "string",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "allowance",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "needed",
        type: "uint256",
      },
    ],
    name: "ERC20InsufficientAllowance",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "balance",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "needed",
        type: "uint256",
      },
    ],
    name: "ERC20InsufficientBalance",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "approver",
        type: "address",
      },
    ],
    name: "ERC20InvalidApprover",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "receiver",
        type: "address",
      },
    ],
    name: "ERC20InvalidReceiver",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
    ],
    name: "ERC20InvalidSender",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
    ],
    name: "ERC20InvalidSpender",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
    ],
    name: "allowance",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "test",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x60806040523480156200001157600080fd5b50604051620014e4380380620014e48339818101604052810190620000379190620001fa565b818181600390816200004a9190620004ca565b5080600490816200005c9190620004ca565b5050505050620005b1565b6000604051905090565b600080fd5b600080fd5b600080fd5b600080fd5b6000601f19601f8301169050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b620000d08262000085565b810181811067ffffffffffffffff82111715620000f257620000f162000096565b5b80604052505050565b60006200010762000067565b9050620001158282620000c5565b919050565b600067ffffffffffffffff82111562000138576200013762000096565b5b620001438262000085565b9050602081019050919050565b60005b838110156200017057808201518184015260208101905062000153565b60008484015250505050565b6000620001936200018d846200011a565b620000fb565b905082815260208101848484011115620001b257620001b162000080565b5b620001bf84828562000150565b509392505050565b600082601f830112620001df57620001de6200007b565b5b8151620001f18482602086016200017c565b91505092915050565b6000806040838503121562000214576200021362000071565b5b600083015167ffffffffffffffff81111562000235576200023462000076565b5b6200024385828601620001c7565b925050602083015167ffffffffffffffff81111562000267576200026662000076565b5b6200027585828601620001c7565b9150509250929050565b600081519050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b60006002820490506001821680620002d257607f821691505b602082108103620002e857620002e76200028a565b5b50919050565b60008190508160005260206000209050919050565b60006020601f8301049050919050565b600082821b905092915050565b600060088302620003527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8262000313565b6200035e868362000313565b95508019841693508086168417925050509392505050565b6000819050919050565b6000819050919050565b6000620003ab620003a56200039f8462000376565b62000380565b62000376565b9050919050565b6000819050919050565b620003c7836200038a565b620003df620003d682620003b2565b84845462000320565b825550505050565b600090565b620003f6620003e7565b62000403818484620003bc565b505050565b5b818110156200042b576200041f600082620003ec565b60018101905062000409565b5050565b601f8211156200047a576200044481620002ee565b6200044f8462000303565b810160208510156200045f578190505b620004776200046e8562000303565b83018262000408565b50505b505050565b600082821c905092915050565b60006200049f600019846008026200047f565b1980831691505092915050565b6000620004ba83836200048c565b9150826002028217905092915050565b620004d5826200027f565b67ffffffffffffffff811115620004f157620004f062000096565b5b620004fd8254620002b9565b6200050a8282856200042f565b600060209050601f8311600181146200054257600084156200052d578287015190505b620005398582620004ac565b865550620005a9565b601f1984166200055286620002ee565b60005b828110156200057c5784890151825560018201915060208501945060208101905062000555565b868310156200059c578489015162000598601f8916826200048c565b8355505b6001600288020188555050505b505050505050565b610f2380620005c16000396000f3fe608060405234801561001057600080fd5b50600436106100a95760003560e01c806340c10f191161007157806340c10f191461016857806370a082311461018457806395d89b41146101b4578063a9059cbb146101d2578063dd62ed3e14610202578063f8a8fd6d14610232576100a9565b806306fdde03146100ae578063095ea7b3146100cc57806318160ddd146100fc57806323b872dd1461011a578063313ce5671461014a575b600080fd5b6100b661023c565b6040516100c39190610b77565b60405180910390f35b6100e660048036038101906100e19190610c32565b6102ce565b6040516100f39190610c8d565b60405180910390f35b6101046102f1565b6040516101119190610cb7565b60405180910390f35b610134600480360381019061012f9190610cd2565b6102fb565b6040516101419190610c8d565b60405180910390f35b61015261032a565b60405161015f9190610d41565b60405180910390f35b610182600480360381019061017d9190610c32565b610333565b005b61019e60048036038101906101999190610d5c565b610341565b6040516101ab9190610cb7565b60405180910390f35b6101bc610389565b6040516101c99190610b77565b60405180910390f35b6101ec60048036038101906101e79190610c32565b61041b565b6040516101f99190610c8d565b60405180910390f35b61021c60048036038101906102179190610d89565b61043e565b6040516102299190610cb7565b60405180910390f35b61023a6104c5565b005b60606003805461024b90610df8565b80601f016020809104026020016040519081016040528092919081815260200182805461027790610df8565b80156102c45780601f10610299576101008083540402835291602001916102c4565b820191906000526020600020905b8154815290600101906020018083116102a757829003601f168201915b5050505050905090565b6000806102d96104c7565b90506102e68185856104cf565b600191505092915050565b6000600254905090565b6000806103066104c7565b90506103138582856104e1565b61031e858585610575565b60019150509392505050565b60006012905090565b61033d8282610669565b5050565b60008060008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020549050919050565b60606004805461039890610df8565b80601f01602080910402602001604051908101604052809291908181526020018280546103c490610df8565b80156104115780601f106103e657610100808354040283529160200191610411565b820191906000526020600020905b8154815290600101906020018083116103f457829003601f168201915b5050505050905090565b6000806104266104c7565b9050610433818585610575565b600191505092915050565b6000600160008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002054905092915050565b565b600033905090565b6104dc83838360016106eb565b505050565b60006104ed848461043e565b90507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff811461056f578181101561055f578281836040517ffb8f41b200000000000000000000000000000000000000000000000000000000815260040161055693929190610e38565b60405180910390fd5b61056e848484840360006106eb565b5b50505050565b600073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16036105e75760006040517f96c6fd1e0000000000000000000000000000000000000000000000000000000081526004016105de9190610e6f565b60405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff16036106595760006040517fec442f050000000000000000000000000000000000000000000000000000000081526004016106509190610e6f565b60405180910390fd5b6106648383836108c2565b505050565b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff16036106db5760006040517fec442f050000000000000000000000000000000000000000000000000000000081526004016106d29190610e6f565b60405180910390fd5b6106e7600083836108c2565b5050565b600073ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff160361075d5760006040517fe602df050000000000000000000000000000000000000000000000000000000081526004016107549190610e6f565b60405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16036107cf5760006040517f94280d620000000000000000000000000000000000000000000000000000000081526004016107c69190610e6f565b60405180910390fd5b81600160008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000208190555080156108bc578273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925846040516108b39190610cb7565b60405180910390a35b50505050565b600073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16036109145780600260008282546109089190610eb9565b925050819055506109e7565b60008060008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020549050818110156109a0578381836040517fe450d38c00000000000000000000000000000000000000000000000000000000815260040161099793929190610e38565b60405180910390fd5b8181036000808673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002081905550505b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610a305780600260008282540392505081905550610a7d565b806000808473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600082825401925050819055505b8173ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef83604051610ada9190610cb7565b60405180910390a3505050565b600081519050919050565b600082825260208201905092915050565b60005b83811015610b21578082015181840152602081019050610b06565b60008484015250505050565b6000601f19601f8301169050919050565b6000610b4982610ae7565b610b538185610af2565b9350610b63818560208601610b03565b610b6c81610b2d565b840191505092915050565b60006020820190508181036000830152610b918184610b3e565b905092915050565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000610bc982610b9e565b9050919050565b610bd981610bbe565b8114610be457600080fd5b50565b600081359050610bf681610bd0565b92915050565b6000819050919050565b610c0f81610bfc565b8114610c1a57600080fd5b50565b600081359050610c2c81610c06565b92915050565b60008060408385031215610c4957610c48610b99565b5b6000610c5785828601610be7565b9250506020610c6885828601610c1d565b9150509250929050565b60008115159050919050565b610c8781610c72565b82525050565b6000602082019050610ca26000830184610c7e565b92915050565b610cb181610bfc565b82525050565b6000602082019050610ccc6000830184610ca8565b92915050565b600080600060608486031215610ceb57610cea610b99565b5b6000610cf986828701610be7565b9350506020610d0a86828701610be7565b9250506040610d1b86828701610c1d565b9150509250925092565b600060ff82169050919050565b610d3b81610d25565b82525050565b6000602082019050610d566000830184610d32565b92915050565b600060208284031215610d7257610d71610b99565b5b6000610d8084828501610be7565b91505092915050565b60008060408385031215610da057610d9f610b99565b5b6000610dae85828601610be7565b9250506020610dbf85828601610be7565b9150509250929050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b60006002820490506001821680610e1057607f821691505b602082108103610e2357610e22610dc9565b5b50919050565b610e3281610bbe565b82525050565b6000606082019050610e4d6000830186610e29565b610e5a6020830185610ca8565b610e676040830184610ca8565b949350505050565b6000602082019050610e846000830184610e29565b92915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b6000610ec482610bfc565b9150610ecf83610bfc565b9250828201905080821115610ee757610ee6610e8a565b5b9291505056fea264697066735822122031090b8da2fff9befe632e4d4c185da7888a40a0d0e305c3d0d4bf97335e0da164736f6c63430008180033";

type TestTokenConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TestTokenConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class TestToken__factory extends ContractFactory {
  constructor(...args: TestTokenConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    name_: string,
    symbol_: string,
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(name_, symbol_, overrides || {});
  }
  override deploy(
    name_: string,
    symbol_: string,
    overrides?: NonPayableOverrides & { from?: string }
  ) {
    return super.deploy(name_, symbol_, overrides || {}) as Promise<
      TestToken & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): TestToken__factory {
    return super.connect(runner) as TestToken__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TestTokenInterface {
    return new Interface(_abi) as TestTokenInterface;
  }
  static connect(address: string, runner?: ContractRunner | null): TestToken {
    return new Contract(address, _abi, runner) as unknown as TestToken;
  }
}
