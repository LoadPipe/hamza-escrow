/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumberish,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  EventFragment,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedLogDescription,
  TypedListener,
  TypedContractMethod,
} from "../common";

export type PaymentStruct = {
  id: BytesLike;
  payer: AddressLike;
  receiver: AddressLike;
  amount: BigNumberish;
  amountRefunded: BigNumberish;
  payerReleased: boolean;
  receiverReleased: boolean;
  released: boolean;
  currency: AddressLike;
};

export type PaymentStructOutput = [
  id: string,
  payer: string,
  receiver: string,
  amount: bigint,
  amountRefunded: bigint,
  payerReleased: boolean,
  receiverReleased: boolean,
  released: boolean,
  currency: string
] & {
  id: string;
  payer: string;
  receiver: string;
  amount: bigint;
  amountRefunded: bigint;
  payerReleased: boolean;
  receiverReleased: boolean;
  released: boolean;
  currency: string;
};

export type PaymentInputStruct = {
  id: BytesLike;
  receiver: AddressLike;
  payer: AddressLike;
  amount: BigNumberish;
};

export type PaymentInputStructOutput = [
  id: string,
  receiver: string,
  payer: string,
  amount: bigint
] & { id: string; receiver: string; payer: string; amount: bigint };

export type MultiPaymentInputStruct = {
  currency: AddressLike;
  payments: PaymentInputStruct[];
};

export type MultiPaymentInputStructOutput = [
  currency: string,
  payments: PaymentInputStructOutput[]
] & { currency: string; payments: PaymentInputStructOutput[] };

export interface PaymentEscrowInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "ADMIN_ROLE"
      | "APPROVER_ROLE"
      | "ARBITER_ROLE"
      | "DAO_ROLE"
      | "PAUSER_ROLE"
      | "REFUNDER_ROLE"
      | "SYSTEM_ROLE"
      | "getPayment"
      | "placeMultiPayments"
      | "refundPayment"
      | "releaseEscrow"
      | "securityContext"
      | "setSecurityContext"
  ): FunctionFragment;

  getEvent(
    nameOrSignatureOrTopic:
      | "EscrowReleased"
      | "PaymentReceived"
      | "PaymentTransferFailed"
      | "PaymentTransferred"
      | "ReleaseAssentGiven"
      | "SecurityContextSet"
  ): EventFragment;

  encodeFunctionData(
    functionFragment: "ADMIN_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "APPROVER_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "ARBITER_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "DAO_ROLE", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "PAUSER_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "REFUNDER_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "SYSTEM_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getPayment",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "placeMultiPayments",
    values: [MultiPaymentInputStruct[]]
  ): string;
  encodeFunctionData(
    functionFragment: "refundPayment",
    values: [BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "releaseEscrow",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "securityContext",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "setSecurityContext",
    values: [AddressLike]
  ): string;

  decodeFunctionResult(functionFragment: "ADMIN_ROLE", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "APPROVER_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "ARBITER_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "DAO_ROLE", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "PAUSER_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "REFUNDER_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "SYSTEM_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getPayment", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "placeMultiPayments",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "refundPayment",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "releaseEscrow",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "securityContext",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setSecurityContext",
    data: BytesLike
  ): Result;
}

export namespace EscrowReleasedEvent {
  export type InputTuple = [
    paymentId: BytesLike,
    amount: BigNumberish,
    fee: BigNumberish
  ];
  export type OutputTuple = [paymentId: string, amount: bigint, fee: bigint];
  export interface OutputObject {
    paymentId: string;
    amount: bigint;
    fee: bigint;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace PaymentReceivedEvent {
  export type InputTuple = [
    paymentId: BytesLike,
    to: AddressLike,
    from: AddressLike,
    currency: AddressLike,
    amount: BigNumberish
  ];
  export type OutputTuple = [
    paymentId: string,
    to: string,
    from: string,
    currency: string,
    amount: bigint
  ];
  export interface OutputObject {
    paymentId: string;
    to: string;
    from: string;
    currency: string;
    amount: bigint;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace PaymentTransferFailedEvent {
  export type InputTuple = [
    paymentId: BytesLike,
    currency: AddressLike,
    amount: BigNumberish
  ];
  export type OutputTuple = [
    paymentId: string,
    currency: string,
    amount: bigint
  ];
  export interface OutputObject {
    paymentId: string;
    currency: string;
    amount: bigint;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace PaymentTransferredEvent {
  export type InputTuple = [
    paymentId: BytesLike,
    currency: AddressLike,
    amount: BigNumberish
  ];
  export type OutputTuple = [
    paymentId: string,
    currency: string,
    amount: bigint
  ];
  export interface OutputObject {
    paymentId: string;
    currency: string;
    amount: bigint;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace ReleaseAssentGivenEvent {
  export type InputTuple = [
    paymentId: BytesLike,
    assentingAddress: AddressLike,
    assentType: BigNumberish
  ];
  export type OutputTuple = [
    paymentId: string,
    assentingAddress: string,
    assentType: bigint
  ];
  export interface OutputObject {
    paymentId: string;
    assentingAddress: string;
    assentType: bigint;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace SecurityContextSetEvent {
  export type InputTuple = [caller: AddressLike, securityContext: AddressLike];
  export type OutputTuple = [caller: string, securityContext: string];
  export interface OutputObject {
    caller: string;
    securityContext: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export interface PaymentEscrow extends BaseContract {
  connect(runner?: ContractRunner | null): PaymentEscrow;
  waitForDeployment(): Promise<this>;

  interface: PaymentEscrowInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  ADMIN_ROLE: TypedContractMethod<[], [string], "view">;

  APPROVER_ROLE: TypedContractMethod<[], [string], "view">;

  ARBITER_ROLE: TypedContractMethod<[], [string], "view">;

  DAO_ROLE: TypedContractMethod<[], [string], "view">;

  PAUSER_ROLE: TypedContractMethod<[], [string], "view">;

  REFUNDER_ROLE: TypedContractMethod<[], [string], "view">;

  SYSTEM_ROLE: TypedContractMethod<[], [string], "view">;

  getPayment: TypedContractMethod<
    [paymentId: BytesLike],
    [PaymentStructOutput],
    "view"
  >;

  placeMultiPayments: TypedContractMethod<
    [multiPayments: MultiPaymentInputStruct[]],
    [void],
    "payable"
  >;

  refundPayment: TypedContractMethod<
    [paymentId: BytesLike, amount: BigNumberish],
    [void],
    "nonpayable"
  >;

  releaseEscrow: TypedContractMethod<
    [paymentId: BytesLike],
    [void],
    "nonpayable"
  >;

  securityContext: TypedContractMethod<[], [string], "view">;

  setSecurityContext: TypedContractMethod<
    [_securityContext: AddressLike],
    [void],
    "nonpayable"
  >;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "ADMIN_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "APPROVER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "ARBITER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "DAO_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "PAUSER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "REFUNDER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "SYSTEM_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "getPayment"
  ): TypedContractMethod<[paymentId: BytesLike], [PaymentStructOutput], "view">;
  getFunction(
    nameOrSignature: "placeMultiPayments"
  ): TypedContractMethod<
    [multiPayments: MultiPaymentInputStruct[]],
    [void],
    "payable"
  >;
  getFunction(
    nameOrSignature: "refundPayment"
  ): TypedContractMethod<
    [paymentId: BytesLike, amount: BigNumberish],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "releaseEscrow"
  ): TypedContractMethod<[paymentId: BytesLike], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "securityContext"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "setSecurityContext"
  ): TypedContractMethod<[_securityContext: AddressLike], [void], "nonpayable">;

  getEvent(
    key: "EscrowReleased"
  ): TypedContractEvent<
    EscrowReleasedEvent.InputTuple,
    EscrowReleasedEvent.OutputTuple,
    EscrowReleasedEvent.OutputObject
  >;
  getEvent(
    key: "PaymentReceived"
  ): TypedContractEvent<
    PaymentReceivedEvent.InputTuple,
    PaymentReceivedEvent.OutputTuple,
    PaymentReceivedEvent.OutputObject
  >;
  getEvent(
    key: "PaymentTransferFailed"
  ): TypedContractEvent<
    PaymentTransferFailedEvent.InputTuple,
    PaymentTransferFailedEvent.OutputTuple,
    PaymentTransferFailedEvent.OutputObject
  >;
  getEvent(
    key: "PaymentTransferred"
  ): TypedContractEvent<
    PaymentTransferredEvent.InputTuple,
    PaymentTransferredEvent.OutputTuple,
    PaymentTransferredEvent.OutputObject
  >;
  getEvent(
    key: "ReleaseAssentGiven"
  ): TypedContractEvent<
    ReleaseAssentGivenEvent.InputTuple,
    ReleaseAssentGivenEvent.OutputTuple,
    ReleaseAssentGivenEvent.OutputObject
  >;
  getEvent(
    key: "SecurityContextSet"
  ): TypedContractEvent<
    SecurityContextSetEvent.InputTuple,
    SecurityContextSetEvent.OutputTuple,
    SecurityContextSetEvent.OutputObject
  >;

  filters: {
    "EscrowReleased(bytes32,uint256,uint256)": TypedContractEvent<
      EscrowReleasedEvent.InputTuple,
      EscrowReleasedEvent.OutputTuple,
      EscrowReleasedEvent.OutputObject
    >;
    EscrowReleased: TypedContractEvent<
      EscrowReleasedEvent.InputTuple,
      EscrowReleasedEvent.OutputTuple,
      EscrowReleasedEvent.OutputObject
    >;

    "PaymentReceived(bytes32,address,address,address,uint256)": TypedContractEvent<
      PaymentReceivedEvent.InputTuple,
      PaymentReceivedEvent.OutputTuple,
      PaymentReceivedEvent.OutputObject
    >;
    PaymentReceived: TypedContractEvent<
      PaymentReceivedEvent.InputTuple,
      PaymentReceivedEvent.OutputTuple,
      PaymentReceivedEvent.OutputObject
    >;

    "PaymentTransferFailed(bytes32,address,uint256)": TypedContractEvent<
      PaymentTransferFailedEvent.InputTuple,
      PaymentTransferFailedEvent.OutputTuple,
      PaymentTransferFailedEvent.OutputObject
    >;
    PaymentTransferFailed: TypedContractEvent<
      PaymentTransferFailedEvent.InputTuple,
      PaymentTransferFailedEvent.OutputTuple,
      PaymentTransferFailedEvent.OutputObject
    >;

    "PaymentTransferred(bytes32,address,uint256)": TypedContractEvent<
      PaymentTransferredEvent.InputTuple,
      PaymentTransferredEvent.OutputTuple,
      PaymentTransferredEvent.OutputObject
    >;
    PaymentTransferred: TypedContractEvent<
      PaymentTransferredEvent.InputTuple,
      PaymentTransferredEvent.OutputTuple,
      PaymentTransferredEvent.OutputObject
    >;

    "ReleaseAssentGiven(bytes32,address,uint8)": TypedContractEvent<
      ReleaseAssentGivenEvent.InputTuple,
      ReleaseAssentGivenEvent.OutputTuple,
      ReleaseAssentGivenEvent.OutputObject
    >;
    ReleaseAssentGiven: TypedContractEvent<
      ReleaseAssentGivenEvent.InputTuple,
      ReleaseAssentGivenEvent.OutputTuple,
      ReleaseAssentGivenEvent.OutputObject
    >;

    "SecurityContextSet(address,address)": TypedContractEvent<
      SecurityContextSetEvent.InputTuple,
      SecurityContextSetEvent.OutputTuple,
      SecurityContextSetEvent.OutputObject
    >;
    SecurityContextSet: TypedContractEvent<
      SecurityContextSetEvent.InputTuple,
      SecurityContextSetEvent.OutputTuple,
      SecurityContextSetEvent.OutputObject
    >;
  };
}