module View.Home exposing
    ( Config
    , channels
    , init
    , presence
    , socket
    , view
    )

import Element as El exposing (Device, DeviceClass(..), Element, Orientation(..))
import Template.Home.Desktop as Desktop
import Template.Home.PhoneLandscape as PhoneLandscape
import Template.Home.PhonePortrait as PhonePortrait


type Config msg
    = Config
        { channels : List (Element msg)
        , presence : List (Element msg)
        , socket : List (Element msg)
        }


init : Config msg
init =
    Config
        { channels = []
        , presence = []
        , socket = []
        }


view : Device -> Config msg -> Element msg
view { class, orientation } (Config config) =
    case ( class, orientation ) of
        ( Phone, Portrait ) ->
            PhonePortrait.view config

        ( Phone, Landscape ) ->
            PhoneLandscape.view config

        _ ->
            Desktop.view config


channels : List (Element msg) -> Config msg -> Config msg
channels channels_ (Config config) =
    Config { config | channels = channels_ }


presence : List (Element msg) -> Config msg -> Config msg
presence presence_ (Config config) =
    Config { config | presence = presence_ }


socket : List (Element msg) -> Config msg -> Config msg
socket socket_ (Config config) =
    Config { config | socket = socket_ }