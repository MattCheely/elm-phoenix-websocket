module Template.Menu.PhonePortrait exposing (render)

import Element as El exposing (Element)
import Element.Font as Font
import Template.Menu.Common as Common


type alias Config msg =
    { options : List ( String, msg )
    , selected : String
    }


render : Config msg -> Element msg
render config =
    El.column
        (List.append
            [ El.paddingEach
                { left = 5
                , top = 16
                , right = 5
                , bottom = 8
                }
            , El.spacing 10
            , Font.size 18
            ]
            Common.containerAttrs
        )
        (List.map (menuItem config.selected) config.options)


menuItem : String -> ( String, msg ) -> Element msg
menuItem selected ( item, msg ) =
    let
        ( attrs, highlight ) =
            if selected == item then
                ( Common.selectedAttrs
                , El.el
                    Common.selectedHighlightAttrs
                    El.none
                )

            else
                ( Common.unselectedAttrs msg
                , El.none
                )
    in
    El.column
        attrs
        [ El.text item
        , highlight
        ]
