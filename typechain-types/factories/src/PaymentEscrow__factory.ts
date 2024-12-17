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
  AddressLike,
  ContractDeployTransaction,
  ContractRunner,
} from "ethers";
import type { NonPayableOverrides } from "../../common";
import type {
  PaymentEscrow,
  PaymentEscrowInterface,
} from "../../src/PaymentEscrow";

const _abi = [
  {
    inputs: [
      {
        internalType: "contract ISecurityContext",
        name: "securityContext",
        type: "address",
      },
      {
        internalType: "contract ISystemSettings",
        name: "settings_",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "x",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "y",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "denominator",
        type: "uint256",
      },
    ],
    name: "PRBMath__MulDivOverflow",
    type: "error",
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
        indexed: true,
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "fee",
        type: "uint256",
      },
    ],
    name: "EscrowReleased",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "currency",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "PaymentReceived",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "address",
        name: "currency",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "PaymentTransferFailed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "address",
        name: "currency",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "PaymentTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "address",
        name: "assentingAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "assentType",
        type: "uint8",
      },
    ],
    name: "ReleaseAssentGiven",
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
    inputs: [
      {
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
    ],
    name: "getPayment",
    outputs: [
      {
        components: [
          {
            internalType: "bytes32",
            name: "id",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "payer",
            type: "address",
          },
          {
            internalType: "address",
            name: "receiver",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "amount",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "amountRefunded",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "payerReleased",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "receiverReleased",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "released",
            type: "bool",
          },
          {
            internalType: "address",
            name: "currency",
            type: "address",
          },
        ],
        internalType: "struct Payment",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "address",
            name: "currency",
            type: "address",
          },
          {
            internalType: "bytes32",
            name: "id",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "receiver",
            type: "address",
          },
          {
            internalType: "address",
            name: "payer",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "amount",
            type: "uint256",
          },
        ],
        internalType: "struct PaymentInput",
        name: "paymentInput",
        type: "tuple",
      },
    ],
    name: "placePayment",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "refundPayment",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "paymentId",
        type: "bytes32",
      },
    ],
    name: "releaseEscrow",
    outputs: [],
    stateMutability: "nonpayable",
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
    stateMutability: "payable",
    type: "receive",
  },
] as const;

const _bytecode =
  "0x60806040523480156200001157600080fd5b5060405162002c7638038062002c7683398181016040528101906200003791906200032c565b62000048826200009160201b60201c565b80603360006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550505062000468565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1603620000f8576040517f26a1e04700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff166391d148546000801b306040518363ffffffff1660e01b8152600401620001389291906200039f565b6020604051808303816000875af115801562000158573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906200017e919062000409565b508073ffffffffffffffffffffffffffffffffffffffff1660008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16146200025e57806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055507f051a1819cad198aaab96867fdf5e127eafe91783a6b4005a8caddb1a94303958620002446200026160201b60201c565b82604051620002559291906200043b565b60405180910390a15b50565b600033905090565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006200029b826200026e565b9050919050565b6000620002af826200028e565b9050919050565b620002c181620002a2565b8114620002cd57600080fd5b50565b600081519050620002e181620002b6565b92915050565b6000620002f4826200028e565b9050919050565b6200030681620002e7565b81146200031257600080fd5b50565b6000815190506200032681620002fb565b92915050565b6000806040838503121562000346576200034562000269565b5b60006200035685828601620002d0565b9250506020620003698582860162000315565b9150509250929050565b6000819050919050565b620003888162000373565b82525050565b62000399816200028e565b82525050565b6000604082019050620003b660008301856200037d565b620003c560208301846200038e565b9392505050565b60008115159050919050565b620003e381620003cc565b8114620003ef57600080fd5b50565b6000815190506200040381620003d8565b92915050565b60006020828403121562000422576200042162000269565b5b60006200043284828501620003f2565b91505092915050565b60006040820190506200045260008301856200038e565b6200046160208301846200038e565b9392505050565b6127fe80620004786000396000f3fe6080604052600436106100c65760003560e01c806375b238fc1161007f578063bf89fc6111610059578063bf89fc6114610242578063e63ab1e91461026b578063e66eefc814610296578063e9c26518146102d3576100cd565b806375b238fc146101d25780638c6380d1146101fd5780639e7f210114610219576100cd565b80634245962b146100d25780634d104adf146100fd5780635960ccf2146101285780636412dd051461015357806372fe99381461017e57806375071d2a146101a7576100cd565b366100cd57005b600080fd5b3480156100de57600080fd5b506100e76102fe565b6040516100f49190611c3a565b60405180910390f35b34801561010957600080fd5b50610112610322565b60405161011f9190611c3a565b60405180910390f35b34801561013457600080fd5b5061013d610346565b60405161014a9190611c3a565b60405180910390f35b34801561015f57600080fd5b5061016861036a565b6040516101759190611cd4565b60405180910390f35b34801561018a57600080fd5b506101a560048036038101906101a09190611d44565b61038e565b005b3480156101b357600080fd5b506101bc61048e565b6040516101c99190611c3a565b60405180910390f35b3480156101de57600080fd5b506101e76104b2565b6040516101f49190611c3a565b60405180910390f35b61021760048036038101906102129190611d95565b6104b9565b005b34801561022557600080fd5b50610240600480360381019061023b9190611e24565b610943565b005b34801561024e57600080fd5b5061026960048036038101906102649190611e64565b610c13565b005b34801561027757600080fd5b506102806110bd565b60405161028d9190611c3a565b60405180910390f35b3480156102a257600080fd5b506102bd60048036038101906102b89190611e64565b6110e1565b6040516102ca9190611f90565b60405180910390f35b3480156102df57600080fd5b506102e8611280565b6040516102f59190611c3a565b60405180910390f35b7f408a36151f841709116a4e8aca4e0202874f7f54687dcb863b1ea4672dc9d8cf81565b7fbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae81565b7fdb9556138406326f00296e13ea2ad7db24ba82381212d816b1a40c23b466b32781565b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000801b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d14854826103d76112a4565b6040518363ffffffff1660e01b81526004016103f4929190611fbb565b6020604051808303816000875af1158015610413573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104379190612010565b61048157806104446112a4565b6040517f074540a2000000000000000000000000000000000000000000000000000000008152600401610478929190611fbb565b60405180910390fd5b61048a826112ac565b5050565b7f5719df9ef2c4678b547f89e4f5ae410dbf400fc51cf3ded434c55f6adea2c43f81565b6000801b81565b6000816080013511610500576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016104f79061209a565b60405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff1681604001602081019061052b91906120e6565b73ffffffffffffffffffffffffffffffffffffffff1603610581576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016105789061215f565b60405180910390fd5b600081600001602081019061059691906120e6565b9050600082608001359050600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff160361061c57803414610617576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161060e9061209a565b60405180910390fd5b6106e2565b60008290508073ffffffffffffffffffffffffffffffffffffffff166323b872dd3330856040518463ffffffff1660e01b815260040161065e9392919061218e565b6020604051808303816000875af115801561067d573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106a19190612010565b6106e0576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016106d790612211565b60405180910390fd5b505b826020013560346000856020013581526020019081526020016000206000015403610742576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016107399061227d565b60405180910390fd5b60006034600085602001358152602001908152602001600020905083606001602081019061077091906120e6565b8160010160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055508360400160208101906107c591906120e6565b8160020160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555083600001602081019061081a91906120e6565b8160050160036101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555083608001358160030181905550836020013581600001819055508060020160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681600001547fdc9b4d1be872943f8c9f8d2d6e8514c595ab627d643f3a0b87b294bc51526ce08360010160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff168460050160039054906101000a900473ffffffffffffffffffffffffffffffffffffffff1685600301546040516109359392919061218e565b60405180910390a350505050565b6000603460008481526020019081526020016000209050600015158160050160029054906101000a900460ff161515146109b2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016109a9906122e9565b60405180910390fd5b600081600301541180156109ce57508060030154816004015411155b15610c0e573373ffffffffffffffffffffffffffffffffffffffff168160020160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1614158015610aee575060008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d148547fbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae336040518363ffffffff1660e01b8152600401610aa9929190611fbb565b6020604051808303816000875af1158015610ac8573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610aec9190612010565b155b15610b2e576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610b2590612355565b60405180910390fd5b600081600401548260030154610b4491906123a4565b905080831115610b89576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610b8090612424565b60405180910390fd5b6000831115610c0c57610bea82600001548360010160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff168460050160039054906101000a900473ffffffffffffffffffffffffffffffffffffffff168661146b565b15610c0b5782826004016000828254610c039190612444565b925050819055505b5b505b505050565b60006034600083815260200190815260200160002090508060020160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614158015610cda57508060010160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614155b8015610da1575060008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d148547fbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae336040518363ffffffff1660e01b8152600401610d5c929190611fbb565b6020604051808303816000875af1158015610d7b573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610d9f9190612010565b155b15610de1576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610dd890612355565b60405180910390fd5b6000816003015411156110b9573373ffffffffffffffffffffffffffffffffffffffff168160020160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1603610eb5578060050160019054906101000a900460ff16610eb45760018160050160016101000a81548160ff021916908315150217905550817fb2b6668db4a99498a43f8f9be5668048bcdf698c6c0994b3e41be911ca9729e8336001604051610eab9291906124c0565b60405180910390a25b5b3373ffffffffffffffffffffffffffffffffffffffff168160010160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1603610f7c578060050160009054906101000a900460ff16610f7b5760018160050160006101000a81548160ff021916908315150217905550817fb2b6668db4a99498a43f8f9be5668048bcdf698c6c0994b3e41be911ca9729e8336002604051610f72929190612524565b60405180910390a25b5b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166391d148547fbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae336040518363ffffffff1660e01b8152600401610ff7929190611fbb565b6020604051808303816000875af1158015611016573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061103a9190612010565b156110af578060050160009054906101000a900460ff166110ae5760018160050160006101000a81548160ff021916908315150217905550817fb2b6668db4a99498a43f8f9be5668048bcdf698c6c0994b3e41be911ca9729e83360036040516110a5929190612588565b60405180910390a25b5b6110b882611634565b5b5050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b6110e9611b8a565b6034600083815260200190815260200160002060405180610120016040529081600082015481526020016001820160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020016002820160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200160038201548152602001600482015481526020016005820160009054906101000a900460ff161515151581526020016005820160019054906101000a900460ff161515151581526020016005820160029054906101000a900460ff161515151581526020016005820160039054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815250509050919050565b7f3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b260381565b600033905090565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1603611312576040517f26a1e04700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff166391d148546000801b306040518363ffffffff1660e01b8152600401611350929190611fbb565b6020604051808303816000875af115801561136f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906113939190612010565b508073ffffffffffffffffffffffffffffffffffffffff1660008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff161461146857806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055507f051a1819cad198aaab96867fdf5e127eafe91783a6b4005a8caddb1a943039586114506112a4565b8260405161145f9291906125b1565b60405180910390a15b50565b60008060009050600083111561162857600073ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff1603611520578473ffffffffffffffffffffffffffffffffffffffff16836040516114d39061260b565b60006040518083038185875af1925050503d8060008114611510576040519150601f19603f3d011682016040523d82523d6000602084013e611515565b606091505b5050809150506115a7565b60008490508073ffffffffffffffffffffffffffffffffffffffff1663a9059cbb87866040518363ffffffff1660e01b8152600401611560929190612620565b6020604051808303816000875af115801561157f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906115a39190612010565b9150505b80156115ec57857ff14ef85bfbd4ab3db29093022b1fa9f520897dd2384673dc48e07327654da0bf85856040516115df929190612620565b60405180910390a2611627565b6040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161161e90612695565b60405180910390fd5b5b80915050949350505050565b60006034600083815260200190815260200160002090508060050160009054906101000a900460ff16801561167757508060050160019054906101000a900460ff165b801561169257508060050160029054906101000a900460ff16155b15611881576000816004015482600301546116ad91906123a4565b90506000806116ba611885565b905060008111156116e2576116d2838261271061197c565b9150828211156116e157600091505b5b600082846116f091906123a4565b90508460050160029054906101000a900460ff1661187c576000811480156117185750600083115b80611777575061177685600001548660020160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff168760050160039054906101000a900473ffffffffffffffffffffffffffffffffffffffff168461146b565b5b1561187b576000831115611822576117c08560000154611795611a93565b8760050160039054906101000a900473ffffffffffffffffffffffffffffffffffffffff168661146b565b1561181d5760018560050160026101000a81548160ff021916908315150217905550857f1679e83f1a5c78898f99c2ad78c3681c0209a5d388b6cc90177b405b9269684a82856040516118149291906126b5565b60405180910390a25b61187a565b60018560050160026101000a81548160ff021916908315150217905550857f1679e83f1a5c78898f99c2ad78c3681c0209a5d388b6cc90177b405b9269684a82856040516118719291906126b5565b60405180910390a25b5b5b505050505b5050565b60008073ffffffffffffffffffffffffffffffffffffffff16603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff161461197457603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166324a9d8536040518163ffffffff1660e01b8152600401602060405180830381865afa158015611949573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061196d91906126f3565b9050611979565b600090505b90565b60008060008019858709858702925082811083820303915050600081036119b7578382816119ad576119ac612720565b5b0492505050611a8c565b8381106119ff578585856040517f7639aaf00000000000000000000000000000000000000000000000000000000081526004016119f69392919061274f565b60405180910390fd5b60008486880990508281118203915080830392506000600186190186169050808604955080840493506001818260000304019050808302841793506000600287600302189050808702600203810290508087026002038102905080870260020381029050808702600203810290508087026002038102905080870260020381029050808502955050505050505b9392505050565b60008073ffffffffffffffffffffffffffffffffffffffff16603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1614611b8257603360009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663430bf08a6040518163ffffffff1660e01b8152600401602060405180830381865afa158015611b57573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611b7b919061279b565b9050611b87565b600090505b90565b60405180610120016040528060008019168152602001600073ffffffffffffffffffffffffffffffffffffffff168152602001600073ffffffffffffffffffffffffffffffffffffffff1681526020016000815260200160008152602001600015158152602001600015158152602001600015158152602001600073ffffffffffffffffffffffffffffffffffffffff1681525090565b6000819050919050565b611c3481611c21565b82525050565b6000602082019050611c4f6000830184611c2b565b92915050565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000819050919050565b6000611c9a611c95611c9084611c55565b611c75565b611c55565b9050919050565b6000611cac82611c7f565b9050919050565b6000611cbe82611ca1565b9050919050565b611cce81611cb3565b82525050565b6000602082019050611ce96000830184611cc5565b92915050565b600080fd5b6000611cff82611c55565b9050919050565b6000611d1182611cf4565b9050919050565b611d2181611d06565b8114611d2c57600080fd5b50565b600081359050611d3e81611d18565b92915050565b600060208284031215611d5a57611d59611cef565b5b6000611d6884828501611d2f565b91505092915050565b600080fd5b600060a08284031215611d8c57611d8b611d71565b5b81905092915050565b600060a08284031215611dab57611daa611cef565b5b6000611db984828501611d76565b91505092915050565b611dcb81611c21565b8114611dd657600080fd5b50565b600081359050611de881611dc2565b92915050565b6000819050919050565b611e0181611dee565b8114611e0c57600080fd5b50565b600081359050611e1e81611df8565b92915050565b60008060408385031215611e3b57611e3a611cef565b5b6000611e4985828601611dd9565b9250506020611e5a85828601611e0f565b9150509250929050565b600060208284031215611e7a57611e79611cef565b5b6000611e8884828501611dd9565b91505092915050565b611e9a81611c21565b82525050565b611ea981611cf4565b82525050565b611eb881611dee565b82525050565b60008115159050919050565b611ed381611ebe565b82525050565b61012082016000820151611ef06000850182611e91565b506020820151611f036020850182611ea0565b506040820151611f166040850182611ea0565b506060820151611f296060850182611eaf565b506080820151611f3c6080850182611eaf565b5060a0820151611f4f60a0850182611eca565b5060c0820151611f6260c0850182611eca565b5060e0820151611f7560e0850182611eca565b50610100820151611f8a610100850182611ea0565b50505050565b600061012082019050611fa66000830184611ed9565b92915050565b611fb581611cf4565b82525050565b6000604082019050611fd06000830185611c2b565b611fdd6020830184611fac565b9392505050565b611fed81611ebe565b8114611ff857600080fd5b50565b60008151905061200a81611fe4565b92915050565b60006020828403121561202657612025611cef565b5b600061203484828501611ffb565b91505092915050565b600082825260208201905092915050565b7f496e76616c6964416d6f756e7400000000000000000000000000000000000000600082015250565b6000612084600d8361203d565b915061208f8261204e565b602082019050919050565b600060208201905081810360008301526120b381612077565b9050919050565b6120c381611cf4565b81146120ce57600080fd5b50565b6000813590506120e0816120ba565b92915050565b6000602082840312156120fc576120fb611cef565b5b600061210a848285016120d1565b91505092915050565b7f496e76616c696452656365697665720000000000000000000000000000000000600082015250565b6000612149600f8361203d565b915061215482612113565b602082019050919050565b600060208201905081810360008301526121788161213c565b9050919050565b61218881611dee565b82525050565b60006060820190506121a36000830186611fac565b6121b06020830185611fac565b6121bd604083018461217f565b949350505050565b7f546f6b656e5061796d656e744661696c65640000000000000000000000000000600082015250565b60006121fb60128361203d565b9150612206826121c5565b602082019050919050565b6000602082019050818103600083015261222a816121ee565b9050919050565b7f4475706c69636174655061796d656e7400000000000000000000000000000000600082015250565b600061226760108361203d565b915061227282612231565b602082019050919050565b600060208201905081810360008301526122968161225a565b9050919050565b7f5061796d656e7420616c72656164792072656c65617365640000000000000000600082015250565b60006122d360188361203d565b91506122de8261229d565b602082019050919050565b60006020820190508181036000830152612302816122c6565b9050919050565b7f556e617574686f72697a65640000000000000000000000000000000000000000600082015250565b600061233f600c8361203d565b915061234a82612309565b602082019050919050565b6000602082019050818103600083015261236e81612332565b9050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b60006123af82611dee565b91506123ba83611dee565b92508282039050818111156123d2576123d1612375565b5b92915050565b7f416d6f756e744578636565646564000000000000000000000000000000000000600082015250565b600061240e600e8361203d565b9150612419826123d8565b602082019050919050565b6000602082019050818103600083015261243d81612401565b9050919050565b600061244f82611dee565b915061245a83611dee565b925082820190508082111561247257612471612375565b5b92915050565b6000819050919050565b600060ff82169050919050565b60006124aa6124a56124a084612478565b611c75565b612482565b9050919050565b6124ba8161248f565b82525050565b60006040820190506124d56000830185611fac565b6124e260208301846124b1565b9392505050565b6000819050919050565b600061250e612509612504846124e9565b611c75565b612482565b9050919050565b61251e816124f3565b82525050565b60006040820190506125396000830185611fac565b6125466020830184612515565b9392505050565b6000819050919050565b600061257261256d6125688461254d565b611c75565b612482565b9050919050565b61258281612557565b82525050565b600060408201905061259d6000830185611fac565b6125aa6020830184612579565b9392505050565b60006040820190506125c66000830185611fac565b6125d36020830184611fac565b9392505050565b600081905092915050565b50565b60006125f56000836125da565b9150612600826125e5565b600082019050919050565b6000612616826125e8565b9150819050919050565b60006040820190506126356000830185611fac565b612642602083018461217f565b9392505050565b7f5061796d656e745472616e736665724661696c65640000000000000000000000600082015250565b600061267f60158361203d565b915061268a82612649565b602082019050919050565b600060208201905081810360008301526126ae81612672565b9050919050565b60006040820190506126ca600083018561217f565b6126d7602083018461217f565b9392505050565b6000815190506126ed81611df8565b92915050565b60006020828403121561270957612708611cef565b5b6000612717848285016126de565b91505092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b6000606082019050612764600083018661217f565b612771602083018561217f565b61277e604083018461217f565b949350505050565b600081519050612795816120ba565b92915050565b6000602082840312156127b1576127b0611cef565b5b60006127bf84828501612786565b9150509291505056fea264697066735822122044482cd137878554fcb32e75c75dde2c21f0c8c2df8eb72936ae41e2f090086664736f6c63430008180033";

type PaymentEscrowConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: PaymentEscrowConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class PaymentEscrow__factory extends ContractFactory {
  constructor(...args: PaymentEscrowConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    securityContext: AddressLike,
    settings_: AddressLike,
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(
      securityContext,
      settings_,
      overrides || {}
    );
  }
  override deploy(
    securityContext: AddressLike,
    settings_: AddressLike,
    overrides?: NonPayableOverrides & { from?: string }
  ) {
    return super.deploy(securityContext, settings_, overrides || {}) as Promise<
      PaymentEscrow & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): PaymentEscrow__factory {
    return super.connect(runner) as PaymentEscrow__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): PaymentEscrowInterface {
    return new Interface(_abi) as PaymentEscrowInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): PaymentEscrow {
    return new Contract(address, _abi, runner) as unknown as PaymentEscrow;
  }
}
