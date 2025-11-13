import { ConnectorConfig, DataConnect, OperationOptions, ExecuteOperationResponse } from 'firebase-admin/data-connect';

export const connectorConfig: ConnectorConfig;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;


export interface Bill_Key {
  id: UUIDString;
  __typename?: 'Bill_Key';
}

export interface CreateUserData {
  user_insert: {
    id: UUIDString;
  };
}

export interface GetMyBillsData {
  bills: ({
    id: UUIDString;
    amountDue: number;
    dueDate: DateString;
    status: string;
  } & Bill_Key)[];
}

export interface ListAllUsersData {
  users: ({
    id: UUIDString;
    username: string;
    email: string;
  } & User_Key)[];
}

export interface Meter_Key {
  id: UUIDString;
  __typename?: 'Meter_Key';
}

export interface PayBillData {
  payment_insert: {
    id: UUIDString;
  };
}

export interface PayBillVariables {
  billId: UUIDString;
  amountPaid: number;
  paymentMethod: string;
  transactionId: string;
}

export interface Payment_Key {
  id: UUIDString;
  __typename?: 'Payment_Key';
}

export interface Reading_Key {
  id: UUIDString;
  __typename?: 'Reading_Key';
}

export interface User_Key {
  id: UUIDString;
  __typename?: 'User_Key';
}

/** Generated Node Admin SDK operation action function for the 'CreateUser' Mutation. Allow users to execute without passing in DataConnect. */
export function createUser(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<CreateUserData>>;
/** Generated Node Admin SDK operation action function for the 'CreateUser' Mutation. Allow users to pass in custom DataConnect instances. */
export function createUser(options?: OperationOptions): Promise<ExecuteOperationResponse<CreateUserData>>;

/** Generated Node Admin SDK operation action function for the 'GetMyBills' Query. Allow users to execute without passing in DataConnect. */
export function getMyBills(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<GetMyBillsData>>;
/** Generated Node Admin SDK operation action function for the 'GetMyBills' Query. Allow users to pass in custom DataConnect instances. */
export function getMyBills(options?: OperationOptions): Promise<ExecuteOperationResponse<GetMyBillsData>>;

/** Generated Node Admin SDK operation action function for the 'PayBill' Mutation. Allow users to execute without passing in DataConnect. */
export function payBill(dc: DataConnect, vars: PayBillVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<PayBillData>>;
/** Generated Node Admin SDK operation action function for the 'PayBill' Mutation. Allow users to pass in custom DataConnect instances. */
export function payBill(vars: PayBillVariables, options?: OperationOptions): Promise<ExecuteOperationResponse<PayBillData>>;

/** Generated Node Admin SDK operation action function for the 'ListAllUsers' Query. Allow users to execute without passing in DataConnect. */
export function listAllUsers(dc: DataConnect, options?: OperationOptions): Promise<ExecuteOperationResponse<ListAllUsersData>>;
/** Generated Node Admin SDK operation action function for the 'ListAllUsers' Query. Allow users to pass in custom DataConnect instances. */
export function listAllUsers(options?: OperationOptions): Promise<ExecuteOperationResponse<ListAllUsersData>>;

