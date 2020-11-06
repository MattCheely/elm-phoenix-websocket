module Template.Menu.TabletLandscape exposing (view)

import Element as El exposing (Attribute, Element)
import List.Extra as List
import Template.Menu.Common as Common


view : Common.Config msg c -> Element msg
view config =
    case config.layout of
        Nothing ->
            toRow config.selected config.onClick config.options

        Just layout ->
            El.column attrs <|
                (List.groupsOfVarying layout config.options
                    |> toRows config.selected config.onClick
                )


attrs : List (Attribute msg)
attrs =
    List.append
        [ El.paddingEach
            { left = 5
            , top = 10
            , right = 5
            , bottom = 0
            }
        , El.spacing 10
        ]
        Common.containerAttrs


toRows : String -> Maybe (String -> msg) -> List (List String) -> List (Element msg)
toRows selected onClick options =
    List.map (toRow selected onClick) options


toRow : String -> Maybe (String -> msg) -> List String -> Element msg
toRow selected onClick options =
    El.wrappedRow
        [ El.width El.fill ]
        (List.map (menuItem selected onClick) options)


menuItem : String -> Maybe (String -> msg) -> String -> Element msg
menuItem selected onClick item =
    let
        ( attrs_, highlight ) =
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
            attrs_
            [ El.text item
            , highlight
            ]
        ]
