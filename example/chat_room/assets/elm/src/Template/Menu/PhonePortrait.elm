module Template.Menu.PhonePortrait exposing (view)

import Element as El exposing (Element)
import Template.Menu.Common as Common


view : Common.Config msg c -> Element msg
view config =
    El.column
        (List.append
            [ El.paddingEach
                { left = 5
                , top = 16
                , right = 5
                , bottom = 8
                }
            , El.spacing 10
            ]
            Common.containerAttrs
        )
    <|
        List.map (menuItem config.selected) config.options


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
