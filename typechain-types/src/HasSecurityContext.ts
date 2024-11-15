/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
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

export interface HasSecurityContextInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "ADMIN_ROLE"
      | "APPROVER_ROLE"
      | "ARBITER_ROLE"
      | "PAUSER_ROLE"
      | "REFUNDER_ROLE"
      | "SYSTEM_ROLE"
      | "UPGRADER_ROLE"
      | "securityContext"
      | "setSecurityContext"
  ): FunctionFragment;

  getEvent(nameOrSignatureOrTopic: "SecurityContextSet"): EventFragment;

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
    functionFragment: "UPGRADER_ROLE",
    values?: undefined
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
  decodeFunctionResult(
    functionFragment: "UPGRADER_ROLE",
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

export interface HasSecurityContext extends BaseContract {
  connect(runner?: ContractRunner | null): HasSecurityContext;
  waitForDeployment(): Promise<this>;

  interface: HasSecurityContextInterface;

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

  PAUSER_ROLE: TypedContractMethod<[], [string], "view">;

  REFUNDER_ROLE: TypedContractMethod<[], [string], "view">;

  SYSTEM_ROLE: TypedContractMethod<[], [string], "view">;

  UPGRADER_ROLE: TypedContractMethod<[], [string], "view">;

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
    nameOrSignature: "PAUSER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "REFUNDER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "SYSTEM_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "UPGRADER_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "securityContext"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "setSecurityContext"
  ): TypedContractMethod<[_securityContext: AddressLike], [void], "nonpayable">;

  getEvent(
    key: "SecurityContextSet"
  ): TypedContractEvent<
    SecurityContextSetEvent.InputTuple,
    SecurityContextSetEvent.OutputTuple,
    SecurityContextSetEvent.OutputObject
  >;

  filters: {
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
