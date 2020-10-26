module Template.Page.Tablet exposing (..)

import Colors.Opaque as Color
import Element as El exposing (Attribute, Device, DeviceClass(..), Element, Orientation(..))
import Element.Background as Background
import Element.Border as Border
import Html exposing (Html)
import Template.Page.Common as Common


view : { body : Element msg } -> Html msg
view { body } =
    El.layout
        (El.padding 20
            :: Common.layoutAttrs
        )
    <|
        El.el
            (List.append
                [ Border.rounded 20
                , Border.shadow
                    { size = 3
                    , blur = 10
                    , color = Color.lightblue
                    , offset = ( 0, 0 )
                    }
                , El.paddingXY 20 0
                ]
                Common.bodyAttrs
            )
            body