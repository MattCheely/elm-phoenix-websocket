module Template.ExampleControls.Common exposing
    ( Config
    , containerAttrs
    , maybeId
    )

import Colors.Opaque as Color
import Element as El exposing (Attribute, Element)
import Element.Border as Border
import Element.Font as Font


type alias Config msg c =
    { c
        | userId : Maybe String
        , elements : List (Element msg)
        , layout : Maybe (List Int)
    }


containerAttrs : List (Attribute msg)
containerAttrs =
    [ Border.color Color.aliceblue
    , Border.widthEach
        { left = 0
        , top = 1
        , right = 0
        , bottom = 1
        }
    , El.paddingXY 0 10
    , El.scrollbarY
    , El.spacing 10
    , El.width El.fill
    ]



{- User ID -}


maybeId : String -> Maybe String -> Element msg
maybeId type_ maybeId_ =
    case maybeId_ of
        Nothing ->
            El.none

        Just id ->
            El.paragraph
                [ Font.size 20
                , Font.center
                , Font.family
                    [ Font.typeface "Varela Round" ]
                ]
                [ El.el
                    [ Font.color Color.lavender ]
                    (El.text (type_ ++ " ID: "))
                , El.el
                    [ Font.color Color.powderblue ]
                    (El.text id)
                ]