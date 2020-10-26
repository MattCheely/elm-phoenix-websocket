module Page.HandleSocketMessages exposing
    ( Model
    , Msg
    , init
    , subscriptions
    , toSession
    , update
    , updateSession
    , view
    )

import Colors.Opaque as Color
import Element as El exposing (Device, DeviceClass(..), Element, Orientation(..))
import Element.Font as Font
import Example exposing (Action(..), Example(..))
import Extra.String as String
import Json.Decode as JD
import Json.Decode.Extra exposing (andMap)
import Json.Encode as JE exposing (Value)
import Json.Encode.Extra exposing (maybe)
import Phoenix
import Phoenix.Socket as Socket
import Route
import Session exposing (Session)
import View.ApplicableFunctions as ApplicableFunctions
import View.Control as Control
import View.Controls as Controls
import View.Example as Example
import View.Feedback as Feedback
import View.Layout as Layout
import View.Menu as Menu
import View.UsefulFunctions as UsefulFunctions
import View.Utils as Utils



{- Init -}


init : Session -> Maybe String -> Maybe ID -> ( Model, Cmd Msg )
init session maybeExample maybeId =
    let
        example =
            case maybeExample of
                Just ex ->
                    Example.fromString ex

                Nothing ->
                    ManageSocketHeartbeat Connect
    in
    getExampleId
        { session = session
        , example = example
        , exampleId = maybeId
        , userId = Nothing
        , heartbeatCount = 0
        , heartbeat = True
        , channelMessages = True
        , channelMessageCount = 0
        , channelMessageList = []
        , presenceMessages = True
        , presenceMessageCount = 0
        , presenceState = []
        }



{- exampleId is a unique ID supplied by "example_controller:control" that
   is used to identify the example in each tab. The tabs can then all join the
   same controlling Channel which routes messages between them.
-}


getExampleId : Model -> ( Model, Cmd Msg )
getExampleId model =
    let
        topic =
            case model.exampleId of
                Just id ->
                    "example_controller:" ++ id

                Nothing ->
                    "example_controller:control"
    in
    case model.example of
        ManagePresenceMessages _ ->
            Phoenix.join topic (Session.phoenix model.session)
                |> updatePhoenix model

        _ ->
            ( model, Cmd.none )



{- Model -}


type alias Model =
    { session : Session
    , example : Example
    , exampleId : Maybe ID
    , userId : Maybe ID
    , heartbeatCount : Int
    , heartbeat : Bool
    , channelMessages : Bool
    , channelMessageCount : Int
    , channelMessageList : List ChannelMsg
    , presenceMessages : Bool
    , presenceMessageCount : Int
    , presenceState : List Presence
    }


type alias ID =
    String


type alias ChannelMsg =
    { topic : Phoenix.Topic
    , event : Phoenix.Event
    , payload : Value
    , joinRef : Maybe String
    , ref : Maybe String
    }


type alias Presence =
    { id : String
    , meta : Meta
    }


type alias Meta =
    { exampleState : ExampleState }


type ExampleState
    = Joined
    | Joining
    | Leaving
    | NotJoined


controllerTopic : Maybe String -> String
controllerTopic maybeId =
    case maybeId of
        Just id ->
            "example_controller:" ++ id

        Nothing ->
            ""


pushConfig : Phoenix.Push
pushConfig =
    { topic = ""
    , event = ""
    , payload = JE.null
    , timeout = Nothing
    , retryStrategy = Phoenix.Drop
    , ref = Nothing
    }



{- Update -}


type Msg
    = GotControlClick Example
    | GotHomeBtnClick
    | GotRemoteControlClick ID Example
    | GotMenuItem Example
    | GotPhoenixMsg Phoenix.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        phoenix =
            Session.phoenix model.session
    in
    case msg of
        GotHomeBtnClick ->
            ( model
            , Route.pushUrl
                (Session.navKey model.session)
                Route.Home
            )

        GotMenuItem example ->
            Phoenix.disconnectAndReset (Just 1000) phoenix
                |> updatePhoenix
                    (reset model)
                |> updateExample example

        GotControlClick example ->
            case example of
                ManageSocketHeartbeat action ->
                    case action of
                        Connect ->
                            phoenix
                                |> Phoenix.setConnectOptions [ Socket.HeartbeatIntervalMillis 1000 ]
                                |> Phoenix.connect
                                |> updatePhoenix model

                        Disconnect ->
                            Phoenix.disconnect (Just 1000) phoenix
                                |> updatePhoenix model
                                |> resetHeartbeatCount

                        On ->
                            Phoenix.heartbeatMessagesOn phoenix
                                |> setHeartbeat True model

                        Off ->
                            Phoenix.heartbeatMessagesOff phoenix
                                |> setHeartbeat False model

                        _ ->
                            ( model, Cmd.none )

                ManageChannelMessages action ->
                    case action of
                        Send ->
                            Phoenix.push
                                { pushConfig
                                    | topic = "example:manage_channel_messages"
                                    , event = "empty_message"
                                }
                                phoenix
                                |> updatePhoenix model

                        On ->
                            Phoenix.socketChannelMessagesOn phoenix
                                |> setChannelMessages True model

                        Off ->
                            Phoenix.socketChannelMessagesOff phoenix
                                |> setChannelMessages False model

                        _ ->
                            ( model, Cmd.none )

                ManagePresenceMessages action ->
                    case action of
                        Join ->
                            Phoenix.join "example:manage_presence_messages" phoenix
                                |> updatePhoenix model

                        Leave ->
                            Phoenix.leave "example:manage_presence_messages" phoenix
                                |> updatePhoenix model

                        On ->
                            Phoenix.socketPresenceMessagesOn phoenix
                                |> setPresenceMessages True model

                        Off ->
                            Phoenix.socketPresenceMessagesOff phoenix
                                |> setPresenceMessages False model

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotRemoteControlClick userId example ->
            case example of
                ManagePresenceMessages action ->
                    case action of
                        Join ->
                            Phoenix.push
                                { pushConfig
                                    | topic = controllerTopic model.exampleId
                                    , event = "join_example"
                                    , payload = encodeUserId userId
                                }
                                phoenix
                                |> updatePhoenix model

                        Leave ->
                            Phoenix.push
                                { pushConfig
                                    | topic = controllerTopic model.exampleId
                                    , event = "leave_example"
                                    , payload = encodeUserId userId
                                }
                                phoenix
                                |> updatePhoenix model

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotPhoenixMsg subMsg ->
            let
                ( newModel, cmd ) =
                    Phoenix.update subMsg phoenix
                        |> updatePhoenix model

                phx =
                    Session.phoenix newModel.session
            in
            case Phoenix.phoenixMsg phx of
                Phoenix.SocketMessage (Phoenix.Heartbeat _) ->
                    ( { newModel | heartbeatCount = newModel.heartbeatCount + 1 }, cmd )

                Phoenix.SocketMessage (Phoenix.ChannelMessage msgInfo) ->
                    ( { newModel
                        | channelMessageCount = newModel.channelMessageCount + 1
                        , channelMessageList = msgInfo :: newModel.channelMessageList
                      }
                    , cmd
                    )

                Phoenix.SocketMessage (Phoenix.PresenceMessage presenceMsg) ->
                    ( { newModel | presenceMessageCount = newModel.presenceMessageCount + 1 }, cmd )

                Phoenix.ChannelResponse (Phoenix.JoinOk "example:manage_presence_messages" payload) ->
                    Phoenix.push
                        { pushConfig
                            | topic = controllerTopic newModel.exampleId
                            , event = "joined_example"
                        }
                        phx
                        |> updatePhoenix newModel
                        |> batch [ cmd ]

                Phoenix.ChannelResponse (Phoenix.LeaveOk "example:manage_presence_messages") ->
                    Phoenix.push
                        { pushConfig
                            | topic = controllerTopic newModel.exampleId
                            , event = "left_example"
                        }
                        phx
                        |> updatePhoenix newModel
                        |> batch [ cmd ]

                {- Remote Control -}
                Phoenix.ChannelResponse (Phoenix.JoinOk topic payload) ->
                    case Phoenix.topicParts topic of
                        ( "example_controller", "control" ) ->
                            case decodeExampleId payload of
                                Ok exampleId ->
                                    Phoenix.batch
                                        [ Phoenix.leave "example_controller:control"
                                        , Phoenix.join (controllerTopic (Just exampleId))
                                        ]
                                        phx
                                        |> updatePhoenix { newModel | exampleId = Just exampleId }
                                        |> batch [ cmd ]

                                _ ->
                                    ( newModel, cmd )

                        ( "example_controller", _ ) ->
                            case decodeUserId payload of
                                Ok id ->
                                    ( { newModel | userId = Just id }
                                    , Cmd.batch
                                        [ cmd
                                        , Cmd.map GotPhoenixMsg <|
                                            Phoenix.addEvents (controllerTopic newModel.exampleId)
                                                [ "join_example"
                                                , "leave_example"
                                                ]
                                                phoenix
                                        ]
                                    )

                                _ ->
                                    ( newModel, cmd )

                        _ ->
                            ( newModel, cmd )

                Phoenix.ChannelEvent _ event payload ->
                    case ( event, decodeUserId payload ) of
                        ( "join_example", Ok userId ) ->
                            if newModel.userId == Just userId then
                                Phoenix.batch
                                    [ Phoenix.join "example:manage_presence_messages"
                                    , Phoenix.push
                                        { pushConfig
                                            | topic = controllerTopic newModel.exampleId
                                            , event = "joining_example"
                                        }
                                    ]
                                    phoenix
                                    |> updatePhoenix newModel

                            else
                                ( newModel, cmd )

                        ( "leave_example", Ok userId ) ->
                            if newModel.userId == Just userId then
                                Phoenix.batch
                                    [ Phoenix.leave "example:manage_presence_messages"
                                    , Phoenix.push
                                        { pushConfig
                                            | topic = controllerTopic newModel.exampleId
                                            , event = "leaving_example"
                                        }
                                    ]
                                    phoenix
                                    |> updatePhoenix newModel

                            else
                                ( newModel, cmd )

                        _ ->
                            ( newModel, cmd )

                Phoenix.PresenceEvent (Phoenix.State topic state) ->
                    case Phoenix.topicParts topic of
                        ( "example_controller", _ ) ->
                            ( { newModel
                                | presenceState =
                                    toPresenceState state
                              }
                            , cmd
                            )

                        _ ->
                            ( newModel, cmd )

                _ ->
                    ( newModel, cmd )


toPresenceState : List Phoenix.Presence -> List Presence
toPresenceState presences =
    List.map toPresence presences


toPresence : Phoenix.Presence -> Presence
toPresence presence =
    { id = presence.id
    , meta =
        case presence.metas of
            -- There will only ever be one meta in the list because each new
            -- join will be considered a new user, so a user cannot have
            -- multiple joins.
            meta :: _ ->
                case decodeMeta meta of
                    Ok m ->
                        m

                    _ ->
                        { exampleState = NotJoined }

            [] ->
                { exampleState = NotJoined }
    }


setChannelMessages : Bool -> Model -> Cmd Phoenix.Msg -> ( Model, Cmd Msg )
setChannelMessages channelMessages model phxCmd =
    ( { model
        | channelMessages = channelMessages
      }
    , Cmd.map GotPhoenixMsg phxCmd
    )


setHeartbeat : Bool -> Model -> Cmd Phoenix.Msg -> ( Model, Cmd Msg )
setHeartbeat heartbeat model phxCmd =
    ( { model
        | heartbeat = heartbeat
      }
    , Cmd.map GotPhoenixMsg phxCmd
    )


setPresenceMessages : Bool -> Model -> Cmd Phoenix.Msg -> ( Model, Cmd Msg )
setPresenceMessages presenceMessages model phxCmd =
    ( { model
        | presenceMessages = presenceMessages
      }
    , Cmd.map GotPhoenixMsg phxCmd
    )


reset : Model -> Model
reset model =
    { model
        | exampleId = Nothing
        , userId = Nothing
        , heartbeatCount = 0
        , heartbeat = True
        , channelMessages = True
        , channelMessageCount = 0
        , channelMessageList = []
        , presenceMessages = True
        , presenceMessageCount = 0
        , presenceState = []
    }


resetHeartbeatCount : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
resetHeartbeatCount ( model, cmd ) =
    ( { model
        | heartbeatCount = 0
      }
    , cmd
    )


updateExample : Example -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
updateExample example ( model, cmd ) =
    getExampleId { model | example = example }
        |> Tuple.mapSecond (\cmd_ -> Cmd.batch [ cmd, cmd_ ])


updatePhoenix : Model -> ( Phoenix.Model, Cmd Phoenix.Msg ) -> ( Model, Cmd Msg )
updatePhoenix model ( phoenix, phoenixCmd ) =
    ( { model
        | session = Session.updatePhoenix phoenix model.session
      }
    , Cmd.map GotPhoenixMsg phoenixCmd
    )


batch : List (Cmd Msg) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
batch cmds ( model, cmd ) =
    ( model
    , Cmd.batch (cmd :: cmds)
    )



{- Decoders -}


decodeExampleId : Value -> Result JD.Error String
decodeExampleId payload =
    JD.decodeValue (JD.field "example_id" JD.string) payload


decodeUserId : Value -> Result JD.Error String
decodeUserId payload =
    JD.decodeValue (JD.field "user_id" JD.string) payload


metaDecoder : JD.Decoder Meta
metaDecoder =
    JD.succeed
        Meta
        |> andMap
            (JD.field "example_state" JD.string
                |> JD.andThen stateDecoder
            )


stateDecoder : String -> JD.Decoder ExampleState
stateDecoder state =
    case state of
        "Joined" ->
            JD.succeed Joined

        "Joining" ->
            JD.succeed Joining

        "Leaving" ->
            JD.succeed Leaving

        "Not Joined" ->
            JD.succeed NotJoined

        _ ->
            JD.fail <|
                "Not a valid Example State: "
                    ++ state


decodeMeta : Value -> Result JD.Error Meta
decodeMeta payload =
    JD.decodeValue metaDecoder payload



{- Encoders -}


encodeUserId : String -> Value
encodeUserId userId =
    JE.object
        [ ( "user_id", JE.string userId ) ]



{- Subscriptions -}


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map GotPhoenixMsg <|
        Phoenix.subscriptions (Session.phoenix model.session)



{- Session -}


toSession : Model -> Session
toSession model =
    model.session


updateSession : Session -> Model -> Model
updateSession session model =
    { model | session = session }



{- Device -}


toDevice : Model -> Device
toDevice model =
    Session.device model.session



{- View -}


view : Model -> { title : String, content : Element Msg }
view model =
    let
        phoenix =
            Session.phoenix model.session

        device =
            toDevice model
    in
    { title = "Handle Socket Messages"
    , content =
        Layout.init
            |> Layout.homeMsg (Just GotHomeBtnClick)
            |> Layout.title "Handle Socket Messages"
            |> Layout.body
                (Example.init
                    |> Example.introduction
                        [ Utils.paragraph
                            [ El.text "By default, the PhoenixJS "
                            , Utils.code device "onMessage"
                            , El.text " handler for the Socket is setup to send all Socket messages through the incoming "
                            , Utils.code device "port"
                            , El.text ". These examples demonstrate controlling the types of messages that are allowed through."
                            ]
                        , Utils.paragraph
                            [ El.text "Clicking on a function will take you to its documentation." ]
                        ]
                    |> Example.menu
                        (Menu.init
                            |> Menu.options
                                [ ( Example.toString (ManageSocketHeartbeat Anything), GotMenuItem (ManageSocketHeartbeat Anything) )
                                , ( Example.toString (ManageChannelMessages Anything), GotMenuItem (ManageChannelMessages Anything) )
                                , ( Example.toString (ManagePresenceMessages Anything), GotMenuItem (ManagePresenceMessages Anything) )
                                ]
                            |> Menu.selected
                                (Example.toString model.example)
                            |> Menu.view device
                        )
                    |> Example.id model.exampleId
                    |> Example.description
                        (description model.example model.exampleId)
                    |> Example.controls
                        (Controls.init
                            |> Controls.userId model.userId
                            |> Controls.elements (controls model device phoenix)
                            |> Controls.order (order model)
                            |> Controls.layouts (layouts model)
                            |> Controls.view device
                        )
                    |> Example.remoteControls
                        (remoteControls model device phoenix)
                    |> Example.info
                        (info model)
                    |> Example.feedback
                        (Feedback.init
                            |> Feedback.elements
                                [ ApplicableFunctions.init
                                    |> ApplicableFunctions.functions (applicableFunctions model.example)
                                    |> ApplicableFunctions.view device
                                , UsefulFunctions.init
                                    |> UsefulFunctions.functions (usefulFunctions model.example phoenix)
                                    |> UsefulFunctions.view device
                                ]
                            |> Feedback.view device
                        )
                    |> Example.view device
                )
            |> Layout.view device
    }


description : Example -> Maybe ID -> List (Element msg)
description example maybeId =
    case example of
        ManageSocketHeartbeat _ ->
            [ Utils.paragraph
                [ El.text "Choose whether to receive the heartbeat as an incoming Socket message. For this example, the heartbeat interval is set at 1 second." ]
            ]

        ManageChannelMessages _ ->
            [ Utils.paragraph
                [ El.text "Choose whether to receive Channel messages as an incoming Socket message. "
                , El.text ""
                ]
            ]

        ManagePresenceMessages _ ->
            [ Utils.paragraph
                [ El.text "Choose whether to receive Presence messages as an incoming Socket message. "
                , El.text "To get the best out of this example, you should open it in mulitple tabs. Click "
                , El.newTabLink
                    [ Font.color Color.dodgerblue
                    , El.mouseOver
                        [ Font.color Color.lavender ]
                    ]
                    { url =
                        case maybeId of
                            Just id ->
                                "/HandleSocketMessages?example=ManagePresenceMessages&id=" ++ id

                            Nothing ->
                                "/HandleSocketMessages?example=ManagePresenceMessages"
                    , label = El.text "here"
                    }
                , El.text " to open a new tab(s). You will then be able to control each tab from the tab you are in."
                ]
            ]

        _ ->
            []


controls : Model -> Device -> Phoenix.Model -> List (Element Msg)
controls { example, heartbeat, channelMessages, presenceMessages } device phoenix =
    case example of
        ManageSocketHeartbeat _ ->
            [ connectControl ManageSocketHeartbeat device phoenix
            , heartbeatOnControl ManageSocketHeartbeat device heartbeat
            , heartbeatOffControl ManageSocketHeartbeat device heartbeat
            , disconnectControl ManageSocketHeartbeat device phoenix
            ]

        ManageChannelMessages _ ->
            [ sendMessageControl ManageChannelMessages device
            , channelMessagesOn ManageChannelMessages device channelMessages
            , channelMessagesOff ManageChannelMessages device channelMessages
            ]

        ManagePresenceMessages _ ->
            [ joinControl ManagePresenceMessages device GotControlClick (not <| Phoenix.channelJoined "example:manage_presence_messages" phoenix)
            , presenceOnControl ManagePresenceMessages device presenceMessages
            , presenceOffControl ManagePresenceMessages device presenceMessages
            , leaveControl ManagePresenceMessages device GotControlClick (Phoenix.channelJoined "example:manage_presence_messages" phoenix)
            ]

        _ ->
            []


order : Model -> List ( DeviceClass, Orientation, List Int )
order { example } =
    case example of
        ManageSocketHeartbeat _ ->
            [ ( Phone, Portrait, [ 0, 2, 3, 1 ] ) ]

        ManagePresenceMessages _ ->
            [ ( Phone, Portrait, [ 0, 2, 3, 1 ] ) ]

        _ ->
            []


layouts : Model -> List ( DeviceClass, Orientation, List Int )
layouts { example } =
    case example of
        ManageSocketHeartbeat _ ->
            [ ( Phone, Portrait, [ 2, 2 ] ) ]

        ManagePresenceMessages _ ->
            [ ( Phone, Portrait, [ 2, 2 ] ) ]

        _ ->
            []


remoteControls : Model -> Device -> Phoenix.Model -> List (Element Msg)
remoteControls { example, userId, presenceState } device phoenix =
    case example of
        ManagePresenceMessages _ ->
            List.filterMap (maybeRemoteControl userId device) presenceState

        _ ->
            []


maybeRemoteControl : Maybe ID -> Device -> Presence -> Maybe (Element Msg)
maybeRemoteControl userId device presence =
    if userId == Just presence.id then
        Nothing

    else
        Just <|
            (Controls.init
                |> Controls.userId (Just presence.id)
                |> Controls.elements
                    [ joinControl ManagePresenceMessages device (GotRemoteControlClick presence.id) (presence.meta.exampleState == NotJoined)
                    , leaveControl ManagePresenceMessages device (GotRemoteControlClick presence.id) (presence.meta.exampleState == Joined)
                    ]
                |> Controls.layouts
                    [ ( Phone, Portrait, [ 2 ] ) ]
                |> Controls.view device
            )


connectControl : (Action -> Example) -> Device -> Phoenix.Model -> Element Msg
connectControl example device phoenix =
    Control.init
        |> Control.label "Connect"
        |> Control.onPress (Just (GotControlClick (example Connect)))
        |> Control.enabled
            (case Phoenix.socketState phoenix of
                Phoenix.Disconnected _ ->
                    True

                _ ->
                    False
            )
        |> Control.view device


disconnectControl : (Action -> Example) -> Device -> Phoenix.Model -> Element Msg
disconnectControl example device phoenix =
    Control.init
        |> Control.label "Disconnect"
        |> Control.onPress (Just (GotControlClick (example Disconnect)))
        |> Control.enabled (Phoenix.socketState phoenix == Phoenix.Connected)
        |> Control.view device


heartbeatOnControl : (Action -> Example) -> Device -> Bool -> Element Msg
heartbeatOnControl example device heartbeat =
    Control.init
        |> Control.label "Heartbeat On"
        |> Control.onPress (Just (GotControlClick (example On)))
        |> Control.enabled (not heartbeat)
        |> Control.view device


heartbeatOffControl : (Action -> Example) -> Device -> Bool -> Element Msg
heartbeatOffControl example device heartbeat =
    Control.init
        |> Control.label "Heartbeat Off"
        |> Control.onPress (Just (GotControlClick (example Off)))
        |> Control.enabled heartbeat
        |> Control.view device


joinControl : (Action -> Example) -> Device -> (Example -> Msg) -> Bool -> Element Msg
joinControl example device onPress enabled =
    Control.init
        |> Control.label "Join Channel"
        |> Control.onPress (Just (onPress (example Join)))
        |> Control.enabled enabled
        |> Control.view device


leaveControl : (Action -> Example) -> Device -> (Example -> Msg) -> Bool -> Element Msg
leaveControl example device onPress enabled =
    Control.init
        |> Control.label "Leave Channel"
        |> Control.onPress (Just (onPress (example Leave)))
        |> Control.enabled enabled
        |> Control.view device


presenceOnControl : (Action -> Example) -> Device -> Bool -> Element Msg
presenceOnControl example device presence =
    Control.init
        |> Control.label "Presence On"
        |> Control.onPress (Just (GotControlClick (example On)))
        |> Control.enabled (not presence)
        |> Control.view device


presenceOffControl : (Action -> Example) -> Device -> Bool -> Element Msg
presenceOffControl example device presence =
    Control.init
        |> Control.label "Presence Off"
        |> Control.onPress (Just (GotControlClick (example Off)))
        |> Control.enabled presence
        |> Control.view device


sendMessageControl : (Action -> Example) -> Device -> Element Msg
sendMessageControl example device =
    Control.init
        |> Control.label "Push Message"
        |> Control.onPress (Just (GotControlClick (example Send)))
        |> Control.enabled True
        |> Control.view device


channelMessagesOn : (Action -> Example) -> Device -> Bool -> Element Msg
channelMessagesOn example device channelMessages =
    Control.init
        |> Control.label "Messages On"
        |> Control.onPress (Just (GotControlClick (example On)))
        |> Control.enabled (not channelMessages)
        |> Control.view device


channelMessagesOff : (Action -> Example) -> Device -> Bool -> Element Msg
channelMessagesOff example device channelMessages =
    Control.init
        |> Control.label "Messages Off"
        |> Control.onPress (Just (GotControlClick (example Off)))
        |> Control.enabled channelMessages
        |> Control.view device


info : Model -> List (Element Msg)
info model =
    let
        container =
            El.el
                [ El.paddingXY 0 10 ]
    in
    case model.example of
        ManageSocketHeartbeat _ ->
            [ container
                (El.text ("Heartbeat Count: " ++ String.fromInt model.heartbeatCount))
            ]

        ManageChannelMessages _ ->
            container
                (El.paragraph
                    []
                    [ El.el [ Font.color Color.darkslateblue ] (El.text "Message Count: ")
                    , El.text (String.fromInt model.channelMessageCount)
                    ]
                )
                :: List.map formatChannelMessages model.channelMessageList

        ManagePresenceMessages _ ->
            [ container
                (El.text ("Message Count: " ++ String.fromInt model.presenceMessageCount))
            ]

        _ ->
            [ El.none ]


formatChannelMessages : ChannelMsg -> Element Msg
formatChannelMessages msg =
    let
        formatted =
            List.map
                (\( label, value ) ->
                    El.paragraph
                        []
                        [ El.el [ Font.color Color.darkslateblue ] (El.text label)
                        , El.text value
                        ]
                )
                [ ( "Topic: ", msg.topic )
                , ( "Event: ", msg.event )
                , ( "Payload: ", JE.encode 2 msg.payload )
                , ( "Join Ref: ", Maybe.withDefault "Nothing" msg.joinRef )
                , ( "Ref: ", Maybe.withDefault "Nothing" msg.ref )
                ]
    in
    El.column
        [ El.spacing 10 ]
    <|
        List.append
            [ El.el
                [ Font.bold ]
                (El.text "Channel Message")
            ]
            formatted


applicableFunctions : Example -> List String
applicableFunctions example =
    case example of
        ManageSocketHeartbeat _ ->
            [ "Phoenix.setConnectOptions"
            , "Phoenix.heartbeatMessagesOn"
            , "Phoenix.heartbeatMessagesOff"
            ]

        ManageChannelMessages _ ->
            [ "Phoenix.push"
            , "Phoenix.socketChannelMessagesOn"
            , "Phoenix.socketChannelMessagesOff"
            ]

        ManagePresenceMessages _ ->
            [ "Phoenix.join"
            , "Phoenix.socketPresenceMessagesOn"
            , "Phoenix.socketPresenceMessagesOff"
            , "Phoeinx.leave"
            ]

        _ ->
            []


usefulFunctions : Example -> Phoenix.Model -> List ( String, String )
usefulFunctions example phoenix =
    case example of
        ManageSocketHeartbeat _ ->
            [ ( "Phoenix.socketState", Phoenix.socketStateToString phoenix )
            , ( "Phoenix.connectionState", Phoenix.connectionState phoenix |> String.printQuoted )
            , ( "Phoenix.isConnected", Phoenix.isConnected phoenix |> String.printBool )
            ]

        ManageChannelMessages _ ->
            [ ( "Phoenix.socketState", Phoenix.socketStateToString phoenix )
            , ( "Phoenix.connectionState", Phoenix.connectionState phoenix |> String.printQuoted )
            , ( "Phoenix.isConnected", Phoenix.isConnected phoenix |> String.printBool )
            , ( "Phoenix.channelJoined", Phoenix.channelJoined "example:manage_channel_messages" phoenix |> String.printBool )
            , ( "Phoenix.joinedChannels", Phoenix.joinedChannels phoenix |> String.printList )
            ]

        ManagePresenceMessages _ ->
            [ ( "Phoenix.socketState", Phoenix.socketStateToString phoenix )
            , ( "Phoenix.connectionState", Phoenix.connectionState phoenix |> String.printQuoted )
            , ( "Phoenix.isConnected", Phoenix.isConnected phoenix |> String.printBool )
            , ( "Phoenix.channelJoined", Phoenix.channelJoined "example:manage_presence_messages" phoenix |> String.printBool )
            , ( "Phoenix.joinedChannels"
              , Phoenix.joinedChannels phoenix
                    |> List.filter (String.startsWith "example:")
                    |> String.printList
              )
            , ( "Phoenix.lastPresenceJoin", Phoenix.lastPresenceJoin "example:manage_presence_messages" phoenix |> String.printMaybe "Presence" )
            , ( "Phoenix.lastPresenceLeave", Phoenix.lastPresenceLeave "example:manage_presence_messages" phoenix |> String.printMaybe "Presence" )
            ]

        _ ->
            []
