import "@typespec/http";
import "@typespec/openapi3";

using TypeSpec.Http;
using OpenAPI;

@doc("""
Electrolux OCP API

Reverse engineered API from Electrolux App

Authorization flow:

`POST /one-account-authorization/api/v1/token` with `client_credentials`

`GET /one-account-user/api/v1/identity-providers` using client credentials token (will retrieve gigya url)

`POST https://socialize.eu1.gigya.com/socialize.getIDs` with api key from previous response

`POST https://accounts.eu1.gigya.com/accounts.login` with api key, username, password, and ids from previous response

`POST https://accounts.eu1.gigya.com/accounts.getJWT` with api key, session toke and ids - will return `id_token`

`POST /one-account-authorization/api/v1/token` with `urn:ietf:params:oauth:grant-type:token-exchange` - will return `accessToken` that will be used in all requests
""")
@service({
  title: "Electrolux OCP service",
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

@discriminator("grantType")
@oneOf
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

enum Brand {
  aeg,
  electrolux,
  frigidaire,
  multibrand,
}

model IdentityProvider {
  domain: string;
  apiKey: string;
  brand: Brand;
  httpRegionalBaseUrl: url;
  webSocketRegionalBaseUrl: url;
  dataCenter: string;
}

@doc("used in header `x-api-key`")
enum ElectroluxApiKey {
  Electrolux: "2AMqwEV5MqVhTKrRCyYfVF8gmKrd2rAmp7cUsfky",
  AEG: "PEdfAP7N7sUc95GJPePDU54e2Pybbt6DZtdww7dz",
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

  @route("one-account-user/api/v1/identity-providers")
  @get
  getIdentityProviders(
    @query brand?: Brand,
    @query email?: string,
  ): IdentityProvider[];
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
  operand_1: TriggerConditionAndOr | TriggerConditionCompareWithCurrentValue;
  operand_2: TriggerConditionAndOr | TriggerConditionCompareWithCurrentValue;
  operator: "and" | "or";
}

model TriggerConditionCompare {
  operand_1: string;
  operand_2: string | boolean;
  operator: "eq" | "lt" | "ge" | "ne";
}

alias TriggerConditionCompareWithCurrentValue<DefaultType = string | boolean> = TriggerConditionCompare | TriggerConditionCompareOp1Value<DefaultType>;

model TriggerConditionCompareOp1Value<Op2Type = string | boolean> {
  operand_1: "value";
  operand_2: Op2Type;
  operator: "eq" | "lt" | "ge" | "ne";
}

enum Access {
  read,
  write,
  readwrite,
}

enum AccessWithDefault {
  ...Access,
  default,
}

model CapabilityTrigger<DefaultType extends string | boolean | int32> {
  action: Record<{
    access: AccessWithDefault;
    values?: Record<{}>;
    default?: string | boolean | int32;
  } | {
    disabled: boolean;
  } | {
    default: string | boolean | int32;
  }>;
  condition: TriggerConditionAndOr | TriggerConditionCompareWithCurrentValue<DefaultType>;
}

model CapabilityTriggerStr is CapabilityTrigger<string>[];
model CapabilityTriggerInt is CapabilityTrigger<int32>[];
model CapabilityTriggerBool is CapabilityTrigger<boolean>[];
model CapabilityTriggerOther is CapabilityTrigger<string | boolean | int32>[];
alias DisabledOptional = {
  disabled?: boolean;
};

model BaseCapabilityForValues {
  ...BaseCapability<never, string | boolean | int32, never>;
  ...DisabledOptional;
}

model BaseCapability<
  AccessOrNever extends Access | never,
  DefaultType extends string | boolean | int32,
  TriggersType extends CapabilityTrigger<string | boolean | int32>[] | never
> {
  access: AccessOrNever;
  default?: DefaultType;
  triggers?: TriggersType;

  // TODO too much nesting, generated types are too deep.
  // TODO extract some generic types to top level
  values?: Record<Record<BaseCapabilityForValues>> | Record<DisabledOptional>;
}

model StrCapability {
  type: "string";
  ...BaseCapability<Access, string, CapabilityTriggerStr>;
}

model NumberCapability {
  type: "number";
  ...BaseCapability<Access, int32, CapabilityTriggerInt>;
  max?: int32;
  min?: int32;
  step?: int32;
}

model IntCapability {
  type: "int";
  ...BaseCapability<Access, int32, CapabilityTriggerInt>;
  max?: int32;
  min?: int32;
  step?: int32;
}

model BooleanCapability {
  type: "boolean";
  ...BaseCapability<Access, boolean, CapabilityTriggerBool>;
}

model OtherCapability {
  type: "careMaintenance" | "alert" | "complex";
  ...BaseCapability<Access, boolean | string | int32, CapabilityTriggerOther>;
}

alias CombinedCapability =
  | StrCapability
  | IntCapability
  | NumberCapability
  | BooleanCapability
  | OtherCapability;

@useAuth([MyOAuth2, ApiKeyAuth<ApiKeyLocation.header, "x-api-key">])
@tag("Applicance")
interface AppliancesApi {
  @route("/appliance/api/v2/appliances")
  @get
  getList(@query includeMetadata?: boolean): Appliance[];

  @route("appliance/api/v2/appliances/{applianceId}")
  @get
  getById(@path applianceId: string): Appliance;

  @route("appliance/api/v2/appliances/{applianceId}/capabilities")
  @get
  getCapabilities(
    @path applianceId: string,
  ): Record<CombinedCapability | Record<CombinedCapability>>;

  @route("appliance/api/v2/appliances/info")
  @get
  getByIds(
    @body applianceIdsList: {
      applianceIds: string[];
    },
  ): Appliance[];

  @route("appliance/api/v2/appliances/{applianceId}/command")
  @put
  executeCommand(
    @path applianceId: string,
    @body command: Record<unknown>,
  ): unknown;
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
