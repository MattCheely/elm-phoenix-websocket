module Template.Menu.Desktop exposing (view)

import Element as El exposing (Element)
import Template.Menu.Common as Common


view : Common.Config msg c -> Element msg
view config =
    El.wrappedRow
        (List.append
            [ El.paddingEach
                { left = 5
                , top = 10
                , right = 5
                , bottom = 0
                }
            , El.spacing 20
            ]
            Common.containerAttrs
        )
        (List.map (menuItem config) config.options)


menuItem : Common.Config msg c -> String -> Element msg
menuItem { selected, onClick } item =
    let
        ( attrs, highlight ) =
            if selected == item then
                ( El.spacing 5
                    :: Common.selectedAttrs
                , El.el
                    Common.selectedHighlightAttrs
                    El.none
                )

            else
                ( El.paddingEach
                    { left = 0
                    , top = 0
                    , right = 0
                    , bottom = 5
                    }
                    :: Common.unselectedAttrs onClick item
                , El.none
                )
    in
    El.row
        [ El.width El.fill ]
        [ El.column
            attrs
            [ El.text item
            , highlight
            ]
        ]
