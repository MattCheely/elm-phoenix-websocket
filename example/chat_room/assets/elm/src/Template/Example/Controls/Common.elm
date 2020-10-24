module Template.Example.Controls.Common exposing
    ( Config
    , containerAttrs
    )

import Colors.Opaque as Color
import Element as El exposing (Attribute, DeviceClass(..), Element, Orientation(..))
import Element.Border as Border
import Template.Example.Common as Common


type alias Config msg c =
    { c
        | elements : List (Element msg)
        , layouts : List ( DeviceClass, Orientation, List Int )
    }


containerAttrs : List (Attribute msg)
containerAttrs =
    [ El.width El.fill
    , El.scrollbarY
    , Border.color Color.aliceblue
    ]
