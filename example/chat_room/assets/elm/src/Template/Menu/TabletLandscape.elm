module Template.Menu.TabletLandscape exposing (view)

import Element as El exposing (Attribute, Element)
import List.Extra as List
import Template.Menu.Common as Common


view : Common.Config msg c -> Element msg
view config =
    case config.layout of
        Nothing ->
            El.wrappedRow attrs <|
                menuItems config.selected config.options

        Just layout ->
            El.column attrs <|
                (List.groupsOfVarying layout config.options
                    |> List.map
                        (\options ->
                            El.row
                                [ El.width El.fill ]
                            <|
                                menuItems config.selected options
                        )
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


menuItems : String -> List ( String, msg ) -> List (Element msg)
menuItems selected options =
    List.map (menuItem selected) options


menuItem : String -> ( String, msg ) -> Element msg
menuItem selected ( item, msg ) =
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
                    :: Common.unselectedAttrs msg
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
