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
} from "../../common";

export interface EscrowSettingsInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "ADMIN_ROLE"
      | "APPROVER_ROLE"
      | "ARBITER_ROLE"
      | "DAO_ROLE"
      | "PAUSER_ROLE"
      | "REFUNDER_ROLE"
      | "SYSTEM_ROLE"
      | "feeBps"
      | "securityContext"
      | "setFeeBps"
      | "setSecurityContext"
      | "setVaultAddress"
      | "vaultAddress"
  ): FunctionFragment;

  getEvent(
    nameOrSignatureOrTopic:
      | "FeeBpsChanged"
      | "SecurityContextSet"
      | "VaultAddressChanged"
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
  encodeFunctionData(functionFragment: "feeBps", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "securityContext",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "setFeeBps",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setSecurityContext",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "setVaultAddress",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "vaultAddress",
    values?: undefined
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
  decodeFunctionResult(functionFragment: "feeBps", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "securityContext",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "setFeeBps", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "setSecurityContext",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setVaultAddress",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "vaultAddress",
    data: BytesLike
  ): Result;
}

export namespace FeeBpsChangedEvent {
  export type InputTuple = [newValue: BigNumberish, changedBy: AddressLike];
  export type OutputTuple = [newValue: bigint, changedBy: string];
  export interface OutputObject {
    newValue: bigint;
    changedBy: string;
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

export namespace VaultAddressChangedEvent {
  export type InputTuple = [newAddress: AddressLike, changedBy: AddressLike];
  export type OutputTuple = [newAddress: string, changedBy: string];
  export interface OutputObject {
    newAddress: string;
    changedBy: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export interface EscrowSettings extends BaseContract {
  connect(runner?: ContractRunner | null): EscrowSettings;
  waitForDeployment(): Promise<this>;

  interface: EscrowSettingsInterface;

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

  feeBps: TypedContractMethod<[], [bigint], "view">;

  securityContext: TypedContractMethod<[], [string], "view">;

  setFeeBps: TypedContractMethod<[feeBps_: BigNumberish], [void], "nonpayable">;

  setSecurityContext: TypedContractMethod<
    [_securityContext: AddressLike],
    [void],
    "nonpayable"
  >;

  setVaultAddress: TypedContractMethod<
    [vaultAddress_: AddressLike],
    [void],
    "nonpayable"
  >;

  vaultAddress: TypedContractMethod<[], [string], "view">;

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
    nameOrSignature: "feeBps"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "securityContext"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "setFeeBps"
  ): TypedContractMethod<[feeBps_: BigNumberish], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "setSecurityContext"
  ): TypedContractMethod<[_securityContext: AddressLike], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "setVaultAddress"
  ): TypedContractMethod<[vaultAddress_: AddressLike], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "vaultAddress"
  ): TypedContractMethod<[], [string], "view">;

  getEvent(
    key: "FeeBpsChanged"
  ): TypedContractEvent<
    FeeBpsChangedEvent.InputTuple,
    FeeBpsChangedEvent.OutputTuple,
    FeeBpsChangedEvent.OutputObject
  >;
  getEvent(
    key: "SecurityContextSet"
  ): TypedContractEvent<
    SecurityContextSetEvent.InputTuple,
    SecurityContextSetEvent.OutputTuple,
    SecurityContextSetEvent.OutputObject
  >;
  getEvent(
    key: "VaultAddressChanged"
  ): TypedContractEvent<
    VaultAddressChangedEvent.InputTuple,
    VaultAddressChangedEvent.OutputTuple,
    VaultAddressChangedEvent.OutputObject
  >;

  filters: {
    "FeeBpsChanged(uint256,address)": TypedContractEvent<
      FeeBpsChangedEvent.InputTuple,
      FeeBpsChangedEvent.OutputTuple,
      FeeBpsChangedEvent.OutputObject
    >;
    FeeBpsChanged: TypedContractEvent<
      FeeBpsChangedEvent.InputTuple,
      FeeBpsChangedEvent.OutputTuple,
      FeeBpsChangedEvent.OutputObject
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

    "VaultAddressChanged(address,address)": TypedContractEvent<
      VaultAddressChangedEvent.InputTuple,
      VaultAddressChangedEvent.OutputTuple,
      VaultAddressChangedEvent.OutputObject
    >;
    VaultAddressChanged: TypedContractEvent<
      VaultAddressChangedEvent.InputTuple,
      VaultAddressChangedEvent.OutputTuple,
      VaultAddressChangedEvent.OutputObject
    >;
  };
}
