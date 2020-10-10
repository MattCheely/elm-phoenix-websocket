module Phoenix.Channel exposing
    ( Topic, Event, Payload, JoinConfig, PortOut, join
    , LeaveConfig, leave
    , PushConfig, push
    , PortIn, Msg(..), subscriptions
    , on, allOn, off, allOff
    )

{-| Use this module to work directly with channels.

Before you can start sending and receiving messages to and from your channels,
you first need to connect to a [socket](Phoenix.Socket), and join the channels.


# Joining

@docs Topic, Event, Payload, JoinConfig, PortOut, join


# Leaving

@docs LeaveConfig, leave


# Pushing

@docs PushConfig, push


# Receiving

@docs PortIn, Msg, subscriptions


# Custom Messages

@docs on, allOn, off, allOff

-}

import Json.Decode as JD
import Json.Encode as JE exposing (Value)
import Json.Encode.Extra exposing (maybe)


{-| A type alias representing the Channel topic that a [Msg](#Msg) is received
from. For example "topic:subTopic".
-}
type alias Topic =
    String


{-| A type alias representing an event sent to, or received from a Channel.
-}
type alias Event =
    String


{-| A type alias representing data that is sent, or received, with a Channel
event.
-}
type alias Payload =
    Value


{-| A type alias representing the config for joining a channel.

  - `topic` - The channel topic id, for example: `"topic:subtopic"`.

  - `payload` - Optional data to be sent to the channel when joining.

  - `events` - A list of events to receive on the Channel.

  - `timeout` - Optional timeout, in ms, before retrying to join if the previous
    attempt failed.

-}
type alias JoinConfig =
    { topic : Topic
    , payload : Maybe Payload
    , events : List Event
    , timeout : Maybe Int
    }


{-| A type alias representing the `port` function required to communicate with
the accompanying JS.

You will find this `port` function in the
[Port](https://github.com/phollyer/elm-phoenix-websocket/tree/master/src/Ports)
module.

-}
type alias PortOut msg =
    { msg : String
    , payload : Value
    }
    -> Cmd msg


{-| Join a channel.

    import Phoenix.Channel as Channel
    import Port

    Channel.join
        { topic = "topic:subtopic"
        , payload = Nothing
        , events = []
        , timeout = Nothing
        }
        Port.pheonixSend

-}
join : JoinConfig -> PortOut msg -> Cmd msg
join { topic, payload, events, timeout } portOut =
    let
        payload_ =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "payload"
                  , case payload of
                        Just data ->
                            data

                        Nothing ->
                            JE.null
                  )
                , ( "events", JE.list JE.string events )
                , ( "timeout"
                  , case timeout of
                        Just t ->
                            JE.int t

                        Nothing ->
                            JE.null
                  )
                ]
    in
    portOut
        { msg = "join"
        , payload = payload_
        }


{-| A type alias representing the config for leaving a channel.

  - `topic` - The channel topic id, for example: `"topic:subtopic"`.
  - `timeout` - Optional timeout, in ms, before retrying to leave if the
    previous attempt failed.

-}
type alias LeaveConfig =
    { topic : String
    , timeout : Maybe Int
    }


{-| Leave a channel.

    import Phoenix.Channel as Channel
    import Port

    Channel.leave
        { topic = "topic:subtopic"
        , timeout = Nothing
        }
        Port.pheonixSend

-}
leave : LeaveConfig -> PortOut msg -> Cmd msg
leave { topic, timeout } portOut =
    let
        payload_ =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "timeout"
                  , case timeout of
                        Just t ->
                            JE.int t

                        Nothing ->
                            JE.null
                  )
                ]
    in
    portOut
        { msg = "leave"
        , payload = payload_
        }


{-| A type alias representing the config for pushing messages to a channel.

  - `topic` - The channel topic id, for example: `"topic:subtopic"`.

  - `event` - The event to send to the channel.

  - `payload` - The data to be sent. If you don't need to send any data, set
    this to
    [Json.Encode.null](https://package.elm-lang.org/packages/elm/json/latest/Json-Encode#null) .

  - `timeout` - Optional timeout, in ms, before retrying to push if the previous
    attempt failed.

  - `ref` - Optional reference you can provide that you can later use to
    identify the response to a push if you're sending lots of the same `msg`s.

-}
type alias PushConfig =
    { topic : String
    , event : String
    , payload : Value
    , timeout : Maybe Int
    , ref : Maybe String
    }


{-| Push a message to a channel.

    import Json.Encode as JE
    import Phoenix.Channel as Channel
    import Port

    Channel.push
        { topic = "topic:subtopic"
        , event = "new_msg"
        , payload = JE.object [("msg", JE.string "Hello World")]
        , timeout = Nothing
        , ref = Nothing
        }
        Port.pheonixSend

-}
push : { a | topic : String, event : String, payload : Value, timeout : Maybe Int, ref : Maybe String } -> PortOut msg -> Cmd msg
push { topic, event, payload, timeout, ref } portOut =
    let
        payload_ =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "event", JE.string event )
                , ( "payload", payload )
                , ( "timeout", maybe JE.int timeout )
                , ( "ref", maybe JE.string ref )
                ]
    in
    portOut
        { msg = "push"
        , payload = payload_
        }


{-| A type alias representing the `port` function required to receive
a [Msg](#Msg) from a channel.

You will find this `port` function in the
[Port](https://github.com/phollyer/elm-phoenix-websocket/tree/master/src/Ports)
module.

-}
type alias PortIn msg =
    ({ topic : Topic
     , msg : String
     , payload : JE.Value
     }
     -> msg
    )
    -> Sub msg


{-| All of the msgs you can receive from the channel.

  - `Topic` - is the channel topic that the message came from.

  - `Event` - is the original `event` that was [push](#push)ed to the
    channel.

  - `Payload` - is the data received from the channel, with the exception of
    `JoinTimout` and `PushTimeout` where it will be the original payload.

`InvalidMsg` means that a msg has been received from the accompanying JS
that cannot be handled. This should not happen, if it does, please raise an
[issue](https://github.com/phollyer/elm-phoenix-websocket/issues).

-}
type Msg
    = JoinOk Topic Payload
    | JoinError Topic Payload
    | JoinTimeout Topic Payload
    | PushOk Topic (Result JD.Error Event) (Result JD.Error Payload) (Result JD.Error Int)
    | PushError Topic (Result JD.Error Event) (Result JD.Error Payload) (Result JD.Error Int)
    | PushTimeout Topic (Result JD.Error Event) (Result JD.Error Payload) (Result JD.Error Int)
    | Message Topic (Result JD.Error Event) (Result JD.Error Payload)
    | Error Topic
    | LeaveOk Topic
    | Closed Topic
    | InvalidMsg Topic String Payload


{-| Subscribe to receive incoming channel [Msg](#Msg)s.

    import Phoenix.Channel as Channel
    import Port

    type Msg
      = ChannelMsg Channel.Msg
      | ...


    subscriptions : Model -> Sub Msg
    subscriptions _ =
        Channel.subscriptions
            ChannelMsg
            Port.channelReceiver

-}
subscriptions : (Msg -> msg) -> PortIn msg -> Sub msg
subscriptions msg portIn =
    portIn <|
        handleIn msg


handleIn : (Msg -> msg) -> { topic : String, msg : String, payload : JE.Value } -> msg
handleIn toMsg { topic, msg, payload } =
    case msg of
        "JoinOk" ->
            toMsg (JoinOk topic payload)

        "JoinError" ->
            toMsg (JoinError topic payload)

        "JoinTimeout" ->
            toMsg (JoinTimeout topic payload)

        "PushOk" ->
            let
                event =
                    JD.decodeValue
                        (JD.field "event" JD.string)
                        payload

                payload_ =
                    JD.decodeValue
                        (JD.field "payload" JD.value)
                        payload

                ref =
                    JD.decodeValue
                        (JD.field "ref" JD.int)
                        payload
            in
            toMsg (PushOk topic event payload_ ref)

        "PushError" ->
            let
                event =
                    JD.decodeValue
                        (JD.field "event" JD.string)
                        payload

                payload_ =
                    JD.decodeValue
                        (JD.field "payload" JD.value)
                        payload

                ref =
                    JD.decodeValue
                        (JD.field "ref" JD.int)
                        payload
            in
            toMsg (PushError topic event payload_ ref)

        "PushTimeout" ->
            let
                event =
                    JD.decodeValue
                        (JD.field "event" JD.string)
                        payload

                payload_ =
                    JD.decodeValue
                        (JD.field "payload" JD.value)
                        payload

                ref =
                    JD.decodeValue
                        (JD.field "ref" JD.int)
                        payload
            in
            toMsg (PushTimeout topic event payload_ ref)

        "Message" ->
            let
                event =
                    JD.decodeValue
                        (JD.field "event" JD.string)
                        payload

                payload_ =
                    JD.decodeValue
                        (JD.field "payload" JD.value)
                        payload
            in
            toMsg (Message topic event payload_)

        "Error" ->
            toMsg (Error topic)

        "LeaveOk" ->
            toMsg (LeaveOk topic)

        "Closed" ->
            toMsg (Closed topic)

        _ ->
            toMsg (InvalidMsg topic msg payload)


{-| Switch an incoming message on.
-}
on : { topic : String, event : String } -> PortOut msg -> Cmd msg
on { topic, event } portOut =
    portOut
        { msg = "on"
        , payload =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "event", JE.string event )
                ]
        }


{-| Switch a list of incoming messages on.
-}
allOn : { topic : String, events : List String } -> PortOut msg -> Cmd msg
allOn { topic, events } portOut =
    portOut
        { msg = "allOn"
        , payload =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "events", JE.list JE.string events )
                ]
        }


{-| Switch an incoming message off.
-}
off : { topic : String, event : String } -> PortOut msg -> Cmd msg
off { topic, event } portOut =
    portOut
        { msg = "off"
        , payload =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "event", JE.string event )
                ]
        }


{-| Switch a list of incoming messages on.
-}
allOff : { topic : String, events : List String } -> PortOut msg -> Cmd msg
allOff { topic, events } portOut =
    portOut
        { msg = "allOff"
        , payload =
            JE.object
                [ ( "topic", JE.string topic )
                , ( "events", JE.list JE.string events )
                ]
        }
