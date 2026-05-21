module StandingOrderExisting exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Table as Table exposing (Row, rowAttr)
import Html exposing (Html, h4, text)
import Html.Attributes exposing (style)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), StandingOrder, StandingOrderForm, User, ValidatedField(..), apiActionDecoder, authHeader, formatBalance, formatBalancePlusFee, standingOrderDecoder, userDecoder)


standingOrderSummary : Model -> StandingOrder -> Row Msg
standingOrderSummary model so =
    let
        tgsIn =
            if model.loggedInUser.id == so.toUserId then
                formatBalance so.seconds

            else
                ""

        tgsOut =
            if model.loggedInUser.id == so.fromUserId then
                if so.status == 3 then
                    formatBalancePlusFee so.seconds so.txFee

                else
                    formatBalance so.seconds

            else
                ""

        possibleButton =
            if Time.posixToMillis so.stopDate == 0 || Time.posixToMillis so.stopDate > Time.posixToMillis so.processedUptoDate then
                Button.button [ Button.primary, Button.onClick <| Types.StopStandingOrder so.id ] [ text "Stop" ]

            else
                text ""
    in
    Table.tr
        [ if so.status > 4 then
            rowAttr (style "color" "grey")

          else
            rowAttr (style "" "")
        ]
        [ Table.td [] [ text (Types.formatDateTime model so.startDate) ]
        , Table.td [] [ text (Types.formatDateTime model so.stopDate) ]
        , Table.td [] [ text (Types.summaryUserGivenAnId model so.fromUserId) ]
        , Table.td [] [ text (Types.summaryUserGivenAnId model so.toUserId) ]
        , Table.td [] [ text (Types.transactionStatus model so.status so.fromUserId so.toUserId) ]
        , Table.td [] [ text tgsIn ]
        , Table.td [] [ text tgsOut ]
        , Table.td [] [ possibleButton ]
        , Table.td [] [ Button.button [ Button.primary, Button.onClick <| ViewStandingOrder so.id ] [ text "View" ] ]
        ]


standingOrderValueDetailedSummary : Model -> StandingOrder -> List (Html Msg)
standingOrderValueDetailedSummary model tx =
    let
        locationId =
            if tx.locationId > 0 then
                tx.locationId

            else
                model.loggedInUser.locationId

        location =
            Maybe.withDefault Types.emptyLivingWageLocation (List.head (List.filter (\lwl -> locationId == lwl.id) model.livingWageLocationList))

        livingWage =
            Types.findLivingWageForLocationIdAndDate model locationId tx.startDate

        national =
            if livingWage.wage > 0 then
                " - "
                    ++ location.name
                    ++ ":"
                    ++ location.symbol
                    ++ Types.formatNationalFloat ((toFloat (Types.summaryTgsAsSeconds model tx.status tx.fromUserId tx.seconds tx.txFee) / 3600) * livingWage.wage)

            else
                ""
    in
    [ text "Value in TGs: "
    , text (Types.formatBalance tx.seconds)
    , text " ("
    , text (Types.timeFromTgs tx.seconds)
    , text national
    , text ")"
    ]


standingOrderTaxDetailedSummary : Model -> StandingOrder -> List (Html Msg)
standingOrderTaxDetailedSummary model tx =
    let
        locationId =
            if tx.locationId > 0 then
                tx.locationId

            else
                model.loggedInUser.locationId

        location =
            Maybe.withDefault Types.emptyLivingWageLocation (List.head (List.filter (\lwl -> locationId == lwl.id) model.livingWageLocationList))

        livingWage =
            Types.findLivingWageForLocationIdAndDate model locationId tx.startDate

        national =
            if livingWage.wage > 0 then
                " - " ++ location.name ++ ":" ++ location.symbol ++ Types.formatNationalTaxFloat (toFloat tx.txFee / 3600 * livingWage.wage)

            else
                ""
    in
    [ text "Tax in TGs: "
    , text (Types.formatBalance tx.txFee)
    , text " ("
    , text (Types.timeFromTgs tx.txFee)
    , text national
    , text ")"
    ]


standingOrderDetailedSummary : Model -> List StandingOrder -> List (Html Msg)
standingOrderDetailedSummary model standOrders =
    case List.head (List.filter (Types.isSelectedStandingOrder model.selectedTxId) standOrders) of
        Just so ->
            let
                confirmed =
                    if Time.posixToMillis so.confirmedDate > 0 then
                        Types.formatDateTime model so.confirmedDate

                    else
                        "(not yet confirmed)"

                processed =
                    if Time.posixToMillis so.processedUptoDate > 0 then
                        Types.formatDateTime model so.processedUptoDate

                    else
                        "(not yet processed)"
            in
            [ Html.div [] [ text "Type: ", text (Types.transactionActivity so.status) ]
            , Html.div [] [ text "Start Date: ", text (Types.formatDateTime model so.startDate) ]
            , Html.div [] [ text "Stop Date: ", text (Types.formatDateTime model so.stopDate) ]
            , Html.div [] [ text "Confirmed Date: ", text confirmed ]
            , Html.div [] [ text "Processed upto Date: ", text processed ]
            , Html.div [] [ text "From: ", text (Types.summaryUserGivenAnId model so.fromUserId) ]
            , Html.div [] [ text "To: ", text (Types.summaryUserGivenAnId model so.toUserId) ]
            , Html.div [] (standingOrderValueDetailedSummary model so)
            , Html.div [] (standingOrderTaxDetailedSummary model so)
            , Html.div [] [ text "Frequency: ", text (Types.frequencyStringFromInt so.frequency) ]
            , Html.div [] [ text "Status: ", text (Types.transactionStatus model so.status so.fromUserId so.toUserId) ]
            , Html.div [] [ text "Description: ", text so.description ]
            ]

        Nothing ->
            [ Html.div []
                [ text "No standing order selected for detailed view"
                ]
            ]


pageStandingOrderList : Model -> List (Html Msg)
pageStandingOrderList model =
    List.concat
        [ [ h4 [] [ text "Recent Standing Orders" ]
          , Table.table
                { options = [ Table.striped, Table.hover ]
                , thead =
                    Table.simpleThead
                        [ Table.th [] [ text "Start Date" ]
                        , Table.th [] [ text "Stop Date" ]
                        , Table.th [] [ text "From" ]
                        , Table.th [] [ text "To" ]
                        , Table.th [] [ text "Status" ]
                        , Table.th [] [ text "TGs In" ]
                        , Table.th [] [ text "TGs Out" ]
                        , Table.th [] [ text "" ]
                        , Table.th [] [ text "" ]
                        ]
                , tbody =
                    Table.tbody []
                        (List.map
                            (standingOrderSummary model)
                            model.pastStandingOrders
                        )
                }
          , Html.br [] []
          ]
        , standingOrderDetailedSummary model model.pastStandingOrders
        , [ Html.br [] []
          , Html.br [] []
          , Html.br [] []
          , Html.br [] []
          ]
        ]



-- HTTP


loadStandingOrders : Model -> Cmd Msg
loadStandingOrders model =
    Http.request
        { method = "GET"
        , url = "/api/standing_orders"
        , expect = Http.expectJson LoadedStandingOrders standingOrderListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


standingOrderListDecoder : Decoder (List StandingOrder)
standingOrderListDecoder =
    list standingOrderDecoder


loadTxUsers : Model -> Cmd Msg
loadTxUsers model =
    Http.request
        { method = "GET"
        , url = "/api/users"
        , expect = Http.expectJson LoadedTxUsers txUsersListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


txUsersListDecoder : Decoder (List User)
txUsersListDecoder =
    list userDecoder


stopStandingOrder : Model -> Int -> Cmd Msg
stopStandingOrder model soId =
    Http.request
        { method = "PATCH"
        , url = "/api/standing_orders/" ++ String.fromInt soId ++ "/stop"
        , expect = Http.expectJson StandingOrderStopped apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
