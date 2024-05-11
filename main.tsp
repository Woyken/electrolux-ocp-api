import "@typespec/http";

using TypeSpec.Http;

@service({
  title: "Widget Service",
})
namespace ElectroluxOCP;

alias MyOAuth2 = OAuth2Auth<
  [
    {
      type: OAuth2FlowType.clientCredentials;
      tokenUrl: "https://api.eu.ocp.electrolux.one/one-account-authorization/api/v1/token";
      refreshUrl: "https://api.eu.ocp.electrolux.one/one-account-authorization/api/v1/token";
    }
  ],
  []
>;

model UserPhoneNumber {
  type: "Mobile" | "Phone";
  number: string | null;
}

model UserMeasurementUnits {
  distanceMeasurementUnit: "KiloMeter" | string;
  tempMeasurementUnit: "Celsius" | string;
  surfaceMeasurementUnit: "SquareMeter" | string;
  weightMeasurementUnit: "KiloGram" | string;
  volumeMeasurementUnit: "CentiLiter" | string;
}

model UserAddress {
  zipCode: string | null;
  state: string;
  city: string | null;
  street: string | null;
  apartmentNumber: string;
  contactCareOf: string;
}

model User {
  firstName: string;
  lastName: string;
  countryCode: string;
  locale: string;
  phoneNumbers: UserPhoneNumber[];
  enabledMarketingChannels: unknown[];
  measurementUnits: UserMeasurementUnits;
  address: UserAddress;
}

union ApiKey {
  API_KEY_ELECTROLUX: "2AMqwEV5MqVhTKrRCyYfVF8gmKrd2rAmp7cUsfky",
  API_KEY_AEG: "PEdfAP7N7sUc95GJPePDU54e2Pybbt6DZtdww7dz",
}

union ClientId {
  AegClientId: "AEGOneApp",
  ElectroluxClientId: "ElxOneApp",
}

model UserToken {
  accessToken: string;
  expiresIn: int32;
  tokenType: "Bearer";
  refreshToken: string;
  scope: "email offline_access eluxiot:*:*:*";
}

union Token {
  clientCredentialsToken: ClientCredentialsToken,
  userToken: UserToken,
}

model ClientCredentialsToken {
  accessToken: string;
  expiresIn: int32;
  tokenType: "Bearer";
  scope: "";
}

model RefreshTokenBody {
  grantType: "refresh_token";
  clientId: ClientId;
  refreshToken: string;
  scope: "";
}

model TokenExchangeBody {
  grantType: "urn:ietf:params:oauth:grant-type:token-exchange";
  clientId: ClientId;
  idToken: string;
  scope: "";
}

model ClientCredentialsTokenBody {
  grantType: "client_credentials";
  clientId: ClientId;
  clientSecret: string;
  scope: "";
}

union TokenBody {
  refreshToken: RefreshTokenBody,
  tokenExchange: TokenExchangeBody,
  clientCredentials: ClientCredentialsTokenBody,
}

model Country {
  name: string;
  countryCode: string;
  legalRegion: string;
  businessRegion: string;
  dataCenter: string;
}

@useAuth(NoAuth)
@tag("Token")
interface TokenApi {
  @route("/one-account-authorization/api/v1/token")
  @post
  tokenEndpoint(@body body: TokenBody): Token | Error;
}

@useAuth([MyOAuth2, ApiKeyAuth<ApiKeyLocation.header, "x-api-key">])
@tag("User")
interface CurrentUserApi {
  @route("/one-account-user/api/v1/users/current")
  @get
  getUser(): User;

  @route("one-account-user/api/v1/countries")
  @get
  getCountries(): Country[];
}

union AppliancePropertyMetadata {
  {
    timestamp: int32,
  },
  Record<AppliancePropertyMetadata>,
  [],
}

model Appliance {
  @visibility("read")
  @path
  applianceId: string;

  applianceData: {
    applianceName: string;
    created: string;
    modelName: string;
  };
  properties: {
    desired: {};
    reported: Record<string | Record<unknown>>;
    metadata: Record<AppliancePropertyMetadata>;
  };
  status: string;
  connectionState: string;
}

model TriggerConditionAndOr {
  operand_1: TriggerConditionAndOr | TriggerConditionCompare;
  operand_2: TriggerConditionAndOr | TriggerConditionCompare;
  operator: "and" | "or";
}

model TriggerConditionCompare {
  // TODO make generic, if op1 is value, op2 will match parent type
  operand_1: "value" | string;

  operand_2: string | boolean;
  operator: "eq" | "lt" | "ge" | "ne";
}

model Capability {
  access: "read" | "write" | "readwrite";
  type:
    | "int"
    | "number"
    | "boolean"
    | "string"
    | "careMaintenance"
    | "alert"
    | "complex";
  triggers?: {
    action: Record<{
      access: "read" | "write" | "readwrite" | "default";
      values?: Record<{}>;
      default?: string | boolean;
    } | {
      disabled: boolean;
    }>;
    condition: TriggerConditionAndOr | TriggerConditionCompare;
  }[];
  values?: Record<{} | Record<Capability & {
    // todo exclude triggers and type
    disabled: boolean;
  }> | {
    disabled: boolean;
  }> | {};

  // TODO, convert to union with type: "number"?
  default?: int32 | boolean | string;

  max?: int32;
  min?: int32;
  step?: int32;
}

@useAuth([MyOAuth2, ApiKeyAuth<ApiKeyLocation.header, "x-api-key">])
@tag("Applicance")
interface AppliancesApi {
  @route("/appliance/api/v2/appliances")
  @get
  getList(@query includeMetadata: boolean): Appliance[];

  @route("appliance/api/v2/appliances/914550543_01:24000076-443E0737CC42")
  @get
  getById(): Appliance;

  @route("appliance/api/v2/appliances/914550543_01:24000076-443E0737CC42/capabilities")
  @get
  getCapabilities(): Record<Capability> | {
    networkInterface: Record<Capability>;
  };
}

@error
model Error2 {
  Message: string;
}

@error
model Error {
  error: string;
  message: string;
  detail: string;
}
