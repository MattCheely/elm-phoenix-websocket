module Example.SimpleJoinAndLeave exposing
    ( Model
    , Msg
    , init
    , subscriptions
    , update
    , view
    )

import Element as El exposing (Device, Element)
import Example.Utils exposing (updatePhoenixWith)
import Extra.String as String
import Json.Encode as JE
import Phoenix
import UI
import View.ApplicableFunctions as ApplicableFunctions
import View.Button as Button
import View.Example as Example
import View.ExampleControls as ExampleControls
import View.Feedback as Feedback
import View.FeedbackContent as FeedbackContent
import View.FeedbackInfo as FeedbackInfo
import View.FeedbackPanel as FeedbackPanel
import View.UsefulFunctions as UsefulFunctions



{- Init -}


init : Device -> Phoenix.Model -> Model
init device phoenix =
    { device = device
    , phoenix = phoenix
    , responses = []
    }



{- Model -}


type alias Model =
    { device : Device
    , phoenix : Phoenix.Model
    , responses : List Phoenix.ChannelResponse
    }


type Action
    = Join
    | Leave



{- Update -}


type Msg
    = GotControlClick Action
    | GotPhoenixMsg Phoenix.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotControlClick action ->
            case action of
                Join ->
                    model.phoenix
                        |> Phoenix.setJoinConfig
                            { topic = "example:join_and_leave_channels"
                            , payload = JE.null
                            , events = []
                            , timeout = Nothing
                            }
                        |> Phoenix.join "example:join_and_leave_channels"
                        |> updatePhoenixWith GotPhoenixMsg model

                Leave ->
                    model.phoenix
                        |> Phoenix.leave "example:join_and_leave_channels"
                        |> updatePhoenixWith GotPhoenixMsg model

        GotPhoenixMsg subMsg ->
            let
                ( newModel, cmd ) =
                    Phoenix.update subMsg model.phoenix
                        |> updatePhoenixWith GotPhoenixMsg model
            in
            case Phoenix.phoenixMsg newModel.phoenix of
                Phoenix.ChannelResponse response ->
                    ( { newModel | responses = response :: newModel.responses }
                    , cmd
                    )

                _ ->
                    ( newModel, cmd )



{- Subscriptions -}


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map GotPhoenixMsg <|
        Phoenix.subscriptions model.phoenix



{- View -}


view : Model -> Element Msg
view model =
    Example.init
        |> Example.description description
        |> Example.controls (controls model)
        |> Example.feedback (feedback model)
        |> Example.view model.device



{- Description -}


description : List (Element msg)
description =
    [ UI.paragraph
        [ El.text "A simple Join to a Channel without sending any params." ]
    ]



{- Controls -}


controls : Model -> Element Msg
controls { device, phoenix } =
    ExampleControls.init
        |> ExampleControls.elements
            [ join device phoenix
            , leave device phoenix
            ]
        |> ExampleControls.view device


join : Device -> Phoenix.Model -> Element Msg
join device phoenix =
    Button.init
        |> Button.label "Join"
        |> Button.onPress (Just (GotControlClick Join))
        |> Button.enabled (not <| Phoenix.channelJoined "example:join_and_leave_channels" phoenix)
        |> Button.view device


leave : Device -> Phoenix.Model -> Element Msg
leave device phoenix =
    Button.init
        |> Button.label "Leave"
        |> Button.onPress (Just (GotControlClick Leave))
        |> Button.enabled (Phoenix.channelJoined "example:join_and_leave_channels" phoenix)
        |> Button.view device



{- Feedback -}


feedback : Model -> Element Msg
feedback { device, phoenix, responses } =
    Feedback.init
        |> Feedback.elements
            [ FeedbackPanel.init
                |> FeedbackPanel.title "Info"
                |> FeedbackPanel.scrollable (channelResponses device responses)
                |> FeedbackPanel.view device
            , FeedbackPanel.init
                |> FeedbackPanel.title "Applicable Functions"
                |> FeedbackPanel.scrollable [ applicableFunctions device ]
                |> FeedbackPanel.view device
            , FeedbackPanel.init
                |> FeedbackPanel.title "Useful Functions"
                |> FeedbackPanel.scrollable [ usefulFunctions device phoenix ]
                |> FeedbackPanel.view device
            ]
        |> Feedback.view device


channelResponses : Device -> List Phoenix.ChannelResponse -> List (Element Msg)
channelResponses device responses =
    List.map (channelResponse device) responses


channelResponse : Device -> Phoenix.ChannelResponse -> Element Msg
channelResponse device response =
    case response of
        Phoenix.JoinOk topic payload ->
            FeedbackContent.init
                |> FeedbackContent.title (Just "ChannelResponse")
                |> FeedbackContent.label "JoinOk"
                |> FeedbackContent.element
                    (FeedbackInfo.init
                        |> FeedbackInfo.topic topic
                        |> FeedbackInfo.payload payload
                        |> FeedbackInfo.view device
                    )
                |> FeedbackContent.view device

        Phoenix.LeaveOk topic ->
            FeedbackContent.init
                |> FeedbackContent.title (Just "ChannelResponse")
                |> FeedbackContent.label "LeaveOk"
                |> FeedbackContent.element
                    (FeedbackInfo.init
                        |> FeedbackInfo.topic topic
                        |> FeedbackInfo.view device
                    )
                |> FeedbackContent.view device

        _ ->
            El.none


applicableFunctions : Device -> Element Msg
applicableFunctions device =
    ApplicableFunctions.init
        |> ApplicableFunctions.functions
            [ "Phoenix.join"
            , "Phoenix.leave"
            ]
        |> ApplicableFunctions.view device


usefulFunctions : Device -> Phoenix.Model -> Element Msg
usefulFunctions device phoenix =
    UsefulFunctions.init
        |> UsefulFunctions.functions
            [ ( "Phoenix.channelJoined", Phoenix.channelJoined "example:join_and_leave_channels" phoenix |> String.printBool )
            , ( "Phoenix.joinedChannels", Phoenix.joinedChannels phoenix |> String.printList )
            ]
        |> UsefulFunctions.view device