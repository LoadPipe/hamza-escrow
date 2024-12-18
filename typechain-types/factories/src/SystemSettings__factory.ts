/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Contract,
  ContractFactory,
  ContractTransactionResponse,
  Interface,
} from "ethers";
import type {
  Signer,
  BigNumberish,
  AddressLike,
  ContractDeployTransaction,
  ContractRunner,
} from "ethers";
import type { NonPayableOverrides } from "../../common";
import type {
  SystemSettings,
  SystemSettingsInterface,
} from "../../src/SystemSettings";

const _abi = [
  {
    inputs: [
      {
        internalType: "contract ISecurityContext",
        name: "securityContext",
        type: "address",
      },
      {
        internalType: "address",
        name: "vaultAddress_",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "feeBps_",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "roleId",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "addr",
        type: "address",
      },
    ],
    name: "UnauthorizedAccess",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddressArgument",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "newValue",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "changedBy",
        type: "address",
      },
    ],
    name: "FeeBpsChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "securityContext",
        type: "address",
      },
    ],
    name: "SecurityContextSet",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "newAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "changedBy",
        type: "address",
      },
    ],
    name: "VaultAddressChanged",
    type: "event",
  },
  {
    inputs: [],
    name: "ADMIN_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "APPROVER_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "ARBITER_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "DAO_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "PAUSER_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "REFUNDER_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "SYSTEM_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "feeBps",
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
    name: "securityContext",
    outputs: [
      {
        internalType: "contract ISecurityContext",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "feeBps_",
        type: "uint256",
      },
    ],
    name: "setFeeBps",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract ISecurityContext",
        name: "_securityContext",
        type: "address",
      },
    ],
    name: "setSecurityContext",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "vaultAddress_",
        type: "address",
      },
    ],
    name: "setVaultAddress",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "vaultAddress",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x60806040523480156200001157600080fd5b50604051620013d9380380620013d98339818101604052810190620000379190620003cd565b62000048836200010b60201b60201c565b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603620000ba576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401620000b1906200048a565b60405180910390fd5b81603360006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555080603481905550505050620005a1565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff160362000172576040517f26a1e04700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff166391d148546000801b306040518363ffffffff1660e01b8152600401620001b2929190620004d8565b6020604051808303816000875af1158015620001d2573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190620001f8919062000542565b508073ffffffffffffffffffffffffffffffffffffffff1660008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1614620002d857806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055507f051a1819cad198aaab96867fdf5e127eafe91783a6b4005a8caddb1a94303958620002be620002db60201b60201c565b82604051620002cf92919062000574565b60405180910390a15b50565b600033905090565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006200031582620002e8565b9050919050565b6000620003298262000308565b9050919050565b6200033b816200031c565b81146200034757600080fd5b50565b6000815190506200035b8162000330565b92915050565b6200036c8162000308565b81146200037857600080fd5b50565b6000815190506200038c8162000361565b92915050565b6000819050919050565b620003a78162000392565b8114620003b357600080fd5b50565b600081519050620003c7816200039c565b92915050565b600080600060608486031215620003e957620003e8620002e3565b5b6000620003f9868287016200034a565b93505060206200040c868287016200037b565b92505060406200041f86828701620003b6565b9150509250925092565b600082825260208201905092915050565b7f496e76616c69645661756c744164647265737300000000000000000000000000600082015250565b60006200047260138362000429565b91506200047f826200043a565b602082019050919050565b60006020820190508181036000830152620004a58162000463565b9050919050565b6000819050919050565b620004c181620004ac565b82525050565b620004d28162000308565b82525050565b6000604082019050620004ef6000830185620004b6565b620004fe6020830184620004c7565b9392505050565b60008115159050919050565b6200051c8162000505565b81146200052857600080fd5b50565b6000815190506200053c8162000511565b92915050565b6000602082840312156200055b576200055a620002e3565b5b60006200056b848285016200052b565b91505092915050565b60006040820190506200058b6000830185620004c7565b6200059a6020830184620004c7565b9392505050565b610e2880620005b16000396000f3fe608060405234801561001057600080fd5b50600436106100cf5760003560e01c806372c27b621161008c57806375b238fc1161006657806375b238fc146101de57806385535cc5146101fc578063e63ab1e914610218578063e9c2651814610236576100cf565b806372c27b621461018857806372fe9938146101a457806375071d2a146101c0576100cf565b806324a9d853146100d45780634245962b146100f2578063430bf08a146101105780634d104adf1461012e5780635960ccf21461014c5780636412dd051461016a575b600080fd5b6100dc610254565b6040516100e99190610a4e565b60405180910390f35b6100fa61025e565b6040516101079190610a82565b60405180910390f35b610118610282565b6040516101259190610ade565b60405180910390f35b6101366102ac565b6040516101439190610a82565b60405180910390f35b6101546102d0565b6040516101619190610a82565b60405180910390f35b6101726102f4565b60405161017f9190610b58565b60405180910390f35b6101a2600480360381019061019d9190610ba4565b610318565b005b6101be60048036038101906101b99190610c0f565b610486565b005b6101c8610586565b6040516101d59190610a82565b60405180910390f35b6101e66105aa565b6040516101f39190610a82565b60405180910390f35b61021660048036038101906102119190610c68565b6105b1565b005b610220610826565b60405161022d9190610a82565b60405180910390f35b61023e61084a565b60405161024b9190610a82565b60405180910390f35b6000603454905090565b7f408a36151f841709116a4e8aca4e0202874f7f54687dcb863b1ea4672dc9d8cf81565b6000603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b7fbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae81565b7fdb9556138406326f00296e13ea2ad7db24ba82381212d816b1a40c23b466b32781565b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b7f3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b260360008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d148548261037e61086e565b6040518363ffffffff1660e01b815260040161039b929190610c95565b6020604051808303816000875af11580156103ba573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103de9190610cf6565b61042857806103eb61086e565b6040517f074540a200000000000000000000000000000000000000000000000000000000815260040161041f929190610c95565b60405180910390fd5b816034541461048257816034819055507fe9935ecaa85c02d153b4c4195bdabdbd7d1b20d824a25c5feb05d273203a17b36034543360405161046b929190610d23565b60405180910390a1603360009054906101000a9050505b5050565b6000801b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d14854826104cf61086e565b6040518363ffffffff1660e01b81526004016104ec929190610c95565b6020604051808303816000875af115801561050b573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061052f9190610cf6565b610579578061053c61086e565b6040517f074540a2000000000000000000000000000000000000000000000000000000008152600401610570929190610c95565b60405180910390fd5b61058282610876565b5050565b7f5719df9ef2c4678b547f89e4f5ae410dbf400fc51cf3ded434c55f6adea2c43f81565b6000801b81565b7f3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b260360008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d148548261061761086e565b6040518363ffffffff1660e01b8152600401610634929190610c95565b6020604051808303816000875af1158015610653573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106779190610cf6565b6106c1578061068461086e565b6040517f074540a20000000000000000000000000000000000000000000000000000000081526004016106b8929190610c95565b60405180910390fd5b8173ffffffffffffffffffffffffffffffffffffffff16603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff161461082257600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610785576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161077c90610da9565b60405180910390fd5b81603360006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055507fa4f45a63389e7031375b7e4422cccea56ab403ecedbd3ce1f0587acaa1999ae3603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1633604051610819929190610dc9565b60405180910390a15b5050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b7f3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b260381565b600033905090565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16036108dc576040517f26a1e04700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff166391d148546000801b306040518363ffffffff1660e01b815260040161091a929190610c95565b6020604051808303816000875af1158015610939573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061095d9190610cf6565b508073ffffffffffffffffffffffffffffffffffffffff1660008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1614610a3257806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055507f051a1819cad198aaab96867fdf5e127eafe91783a6b4005a8caddb1a94303958610a1a61086e565b82604051610a29929190610dc9565b60405180910390a15b50565b6000819050919050565b610a4881610a35565b82525050565b6000602082019050610a636000830184610a3f565b92915050565b6000819050919050565b610a7c81610a69565b82525050565b6000602082019050610a976000830184610a73565b92915050565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000610ac882610a9d565b9050919050565b610ad881610abd565b82525050565b6000602082019050610af36000830184610acf565b92915050565b6000819050919050565b6000610b1e610b19610b1484610a9d565b610af9565b610a9d565b9050919050565b6000610b3082610b03565b9050919050565b6000610b4282610b25565b9050919050565b610b5281610b37565b82525050565b6000602082019050610b6d6000830184610b49565b92915050565b600080fd5b610b8181610a35565b8114610b8c57600080fd5b50565b600081359050610b9e81610b78565b92915050565b600060208284031215610bba57610bb9610b73565b5b6000610bc884828501610b8f565b91505092915050565b6000610bdc82610abd565b9050919050565b610bec81610bd1565b8114610bf757600080fd5b50565b600081359050610c0981610be3565b92915050565b600060208284031215610c2557610c24610b73565b5b6000610c3384828501610bfa565b91505092915050565b610c4581610abd565b8114610c5057600080fd5b50565b600081359050610c6281610c3c565b92915050565b600060208284031215610c7e57610c7d610b73565b5b6000610c8c84828501610c53565b91505092915050565b6000604082019050610caa6000830185610a73565b610cb76020830184610acf565b9392505050565b60008115159050919050565b610cd381610cbe565b8114610cde57600080fd5b50565b600081519050610cf081610cca565b92915050565b600060208284031215610d0c57610d0b610b73565b5b6000610d1a84828501610ce1565b91505092915050565b6000604082019050610d386000830185610a3f565b610d456020830184610acf565b9392505050565b600082825260208201905092915050565b7f496e76616c696456616c75650000000000000000000000000000000000000000600082015250565b6000610d93600c83610d4c565b9150610d9e82610d5d565b602082019050919050565b60006020820190508181036000830152610dc281610d86565b9050919050565b6000604082019050610dde6000830185610acf565b610deb6020830184610acf565b939250505056fea26469706673582212204362144a4993086ff430b3e6ad04f55bd91e44b331e2717768fc1822ee04936464736f6c63430008180033";

type SystemSettingsConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: SystemSettingsConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class SystemSettings__factory extends ContractFactory {
  constructor(...args: SystemSettingsConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    securityContext: AddressLike,
    vaultAddress_: AddressLike,
    feeBps_: BigNumberish,
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(
      securityContext,
      vaultAddress_,
      feeBps_,
      overrides || {}
    );
  }
  override deploy(
    securityContext: AddressLike,
    vaultAddress_: AddressLike,
    feeBps_: BigNumberish,
    overrides?: NonPayableOverrides & { from?: string }
  ) {
    return super.deploy(
      securityContext,
      vaultAddress_,
      feeBps_,
      overrides || {}
    ) as Promise<
      SystemSettings & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): SystemSettings__factory {
    return super.connect(runner) as SystemSettings__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): SystemSettingsInterface {
    return new Interface(_abi) as SystemSettingsInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): SystemSettings {
    return new Contract(address, _abi, runner) as unknown as SystemSettings;
  }
}
