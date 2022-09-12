
import Foundation
import AWSLexRuntimeV2
import AWSClientRuntime
import ClientRuntime
import Gzip

public struct MyLexV2Response {
    let message: String
    let input: String
}

struct MyCustomCredentialsProvider: CredentialsProvider {
    private let accessKey: String
    private let accessSecret: String

    public init(accessKey: String, accessSecret: String) {
        self.accessKey = accessKey
        self.accessSecret = accessSecret
    }
    
    func getCredentials() async throws -> AWSCredentials {
        return AWSCredentials(accessKey: self.accessKey, secret: self.accessSecret, expirationTimeout: 30)
    }
}

public class MyLexV2 {
    // private var client: CognitoIdentityClient?
    private var lex: MyLexV2Client?
    private let region: String
    private let localeId: String
    private let sessionId: String = UUID().uuidString
    private var configuration: LexRuntimeV2Client.LexRuntimeV2ClientConfiguration?
    private let botAliasId: String
    private let botId: String

    public init(botId: String, botAliasId: String, localeId: String = "en_US", region: String = "us-east-1", accessKey: String, accessSecret: String) throws {
        self.botId = botId
        self.botAliasId = botAliasId
        self.localeId = localeId
        self.region = region
        let credentialsProvider = try AWSCredentialsProvider.fromCustom(MyCustomCredentialsProvider(accessKey: accessKey, accessSecret: accessSecret))
        print("create client config")
        let config = try LexRuntimeV2Client.LexRuntimeV2ClientConfiguration(region: region, credentialsProvider: credentialsProvider)
        print("create Lex V2 client")
        self.lex = MyLexV2Client(config: config)
    }

    public func startUtterance(sessionId: String, completion: @escaping (MyLexV2Response?) -> Void) {
        Task {
            do {
                guard let urlPath = Bundle.main.url(forResource: "test", withExtension: "pcm") else { return }
                guard let fileHandle = try? FileHandle(forReadingFrom: urlPath) else { return }
//                guard let fileHandle = try? FileHandle(forReadingAtPath: "/Users/prashantahar/Documents/NativeVoice/AWSLexV2/AWSLexV2/test.pcm") else { return }
                let stream = ClientRuntime.ByteStream.from(fileHandle: fileHandle)
                let input = RecognizeUtteranceInput(botAliasId: botAliasId,
                                                    botId: botId,
                                                    inputStream: stream,
                                                    localeId: localeId,
                                                    requestContentType: "audio/l16;rate=16000;channels=1",
                                                    responseContentType: "text/plain;charset=utf-8",//"audio/pcm",
                                                    sessionId: sessionId)
                // input.withHeader(name:"x-amz-content-sha256", value: "UNSIGNED-PAYLOAD")
                let response = try await lex?.recognizeUtterance(input: input)
                
                if let message = response?.messages,
                   let inputTranscript = response?.inputTranscript {
                    if let data = Data(base64Encoded: message),
                       let inputTranscriptData = Data(base64Encoded: inputTranscript) {

                        let decomDataMessage: Data
                        let decomDataInput: Data
                        if data.isGzipped, inputTranscriptData.isGzipped {
                            decomDataMessage = try! data.gunzipped()
                            decomDataInput = try! inputTranscriptData.gunzipped()
                        } else {
                            decomDataMessage = data
                            decomDataInput = inputTranscriptData
                        }
                        let textMessage = String(decoding: decomDataMessage, as: UTF8.self)
                        let textInput = String(decoding: decomDataInput, as: UTF8.self)
                        completion(MyLexV2Response(message: textMessage, input: textInput))
                    }
                } else {
                    completion(nil)
                }
                print("response: \(String(describing: response))")
            } catch {
                print("error: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}

public class MyLexV2Client {
    public static let clientName = "LexRuntimeV2Client"
    let client: ClientRuntime.SdkHttpClient
    let config: AWSClientRuntime.AWSClientConfiguration
    let serviceName = "Lex Runtime V2"
    let encoder: ClientRuntime.RequestEncoder
    let decoder: ClientRuntime.ResponseDecoder

    public init(config: AWSClientRuntime.AWSClientConfiguration) {
        client = ClientRuntime.SdkHttpClient(engine: config.httpClientEngine, config: config.httpClientConfiguration)
        let encoder = ClientRuntime.JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        self.encoder = config.encoder ?? encoder
        let decoder = ClientRuntime.JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        self.decoder = config.decoder ?? decoder
        self.config = config
    }

    public convenience init(region: Swift.String) throws {
        let config = try LexRuntimeV2Client.LexRuntimeV2ClientConfiguration(region: region)
        self.init(config: config)
    }

    public convenience init() async throws {
        let config = try await LexRuntimeV2Client.LexRuntimeV2ClientConfiguration()
        self.init(config: config)
    }

    deinit {
        client.close()
    }
    
    public func recognizeUtterance(input: RecognizeUtteranceInput) async throws -> RecognizeUtteranceOutputResponse
    {
        let context = ClientRuntime.HttpContextBuilder()
                      .withEncoder(value: encoder)
                      .withDecoder(value: decoder)
                      .withMethod(value: .post)
                      .withServiceName(value: serviceName)
                      .withOperation(value: "recognizeUtterance")
                      .withIdempotencyTokenGenerator(value: config.idempotencyTokenGenerator)
                      .withLogger(value: config.logger)
                      .withCredentialsProvider(value: config.credentialsProvider)
                      .withRegion(value: config.region)
                      .withSigningName(value: "lex")
                      .withSigningRegion(value: config.signingRegion)
        var operation = ClientRuntime.OperationStack<RecognizeUtteranceInput, RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>(id: "recognizeUtterance")
        operation.initializeStep.intercept(position: .after, middleware: ClientRuntime.URLPathMiddleware<RecognizeUtteranceInput, RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>())
        operation.initializeStep.intercept(position: .after, middleware: ClientRuntime.URLHostMiddleware<RecognizeUtteranceInput, RecognizeUtteranceOutputResponse>())
        operation.buildStep.intercept(position: .before, middleware: AWSClientRuntime.EndpointResolverMiddleware<RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>(endpointResolver: config.endpointResolver, serviceId: serviceName))
        let apiMetadata = AWSClientRuntime.APIMetadata(serviceId: serviceName, version: "1.0")
        operation.buildStep.intercept(position: .before, middleware: AWSClientRuntime.UserAgentMiddleware(metadata: AWSClientRuntime.AWSUserAgentMetadata.fromEnv(apiMetadata: apiMetadata, frameworkMetadata: config.frameworkMetadata)))
        operation.serializeStep.intercept(position: .after, middleware: ClientRuntime.HeaderMiddleware<RecognizeUtteranceInput, RecognizeUtteranceOutputResponse>())
        operation.serializeStep.intercept(position: .after, middleware: ContentTypeMiddleware<RecognizeUtteranceInput, RecognizeUtteranceOutputResponse>(contentType: "application/octet-stream"))
        operation.serializeStep.intercept(position: .after, middleware: RecognizeUtteranceInputBodyMiddleware())
        operation.finalizeStep.intercept(position: .before, middleware: ClientRuntime.ContentLengthMiddleware())
        operation.finalizeStep.intercept(position: .after, middleware: AWSClientRuntime.RetryerMiddleware<RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>(retryer: config.retryer))
        let sigv4Config = AWSClientRuntime.SigV4Config(unsignedBody: true)
        operation.finalizeStep.intercept(position: .before, middleware: AWSClientRuntime.SigV4Middleware<RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>(config: sigv4Config))
        operation.finalizeStep.intercept(position: .after, middleware: MyUnsignedPayloadMiddleware())
        operation.deserializeStep.intercept(position: .before, middleware: ClientRuntime.LoggerMiddleware<RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>(clientLogMode: config.clientLogMode))
        operation.deserializeStep.intercept(position: .after, middleware: ClientRuntime.DeserializeMiddleware<RecognizeUtteranceOutputResponse, RecognizeUtteranceOutputError>())
        let result = try await operation.handleMiddleware(context: context.build(), input: input, next: client.getHandler())
        return result
    }

}


public struct MyUnsignedPayloadMiddleware<OperationStackOutput: HttpResponseBinding>: Middleware {
    public let id: String = "MyUnsignedPayload"
    
    private let sha256HeaderName = "x-amz-content-sha256"
    
    public init() {}
    
    public func handle<H>(context: Context,
                          input: MInput,
                          next: H) async throws -> MOutput
    where H: Handler,
    Self.MInput == H.Input,
    Self.MOutput == H.Output,
    Self.Context == H.Context {
        
        input.withHeader(name: sha256HeaderName, value: "UNSIGNED-PAYLOAD")
        
        return try await next.handle(context: context, input: input)
    }
    
    public typealias MInput = SdkHttpRequestBuilder
    public typealias MOutput = OperationOutput<OperationStackOutput>
    public typealias Context = HttpContext
}
