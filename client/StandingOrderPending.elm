module StandingOrderPending exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Table as Table exposing (Row)
import FormatNumber exposing (format)
import Html exposing (Html, h4, text)
import Http exposing (emptyBody)
import StandingOrderExisting
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), StandingOrder, Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, tgsLocale)


pendingStandingOrderSummary : Model -> StandingOrder -> Row Msg
pendingStandingOrderSummary model so =
    let
        stopDate =
            if Time.posixToMillis so.stopDate > 0 then
                Types.formatDateTime model so.stopDate

            else
                "(forever)"
    in
    Table.tr []
        [ Table.td [] [ text (Types.formatDateTime model so.startDate) ]
        , Table.td [] [ text stopDate ]
        , Table.td [] [ text "F: ", text (Types.summaryUserGivenAnId model so.fromUserId), Html.br [] [], text "T: ", text (Types.summaryUserGivenAnId model so.toUserId) ]
        , Table.td [] [ text (format tgsLocale (Types.tgsFromStandingOrder model so)) ]
        , Table.td [] [ text (Types.frequencyStringFromInt so.frequency) ]
        , Table.td [] [ text (Types.transactionStatus model so.status so.fromUserId so.toUserId) ]
        , Table.td []
            [ if (so.status == 1 && so.toUserId == model.loggedInUser.id) || (so.status == 2 && so.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| AcceptStandingOrder so.id ] [ text "Accept" ]

              else
                text ""
            ]
        , Table.td []
            [ if (so.status == 1 && so.toUserId == model.loggedInUser.id) || (so.status == 2 && so.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| RejectStandingOrder so.id ] [ text "Reject" ]

              else
                text ""
            ]
        , Table.td []
            [ if (so.status == 2 && so.toUserId == model.loggedInUser.id) || (so.status == 1 && so.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| WithdrawStandingOrder so.id ] [ text "Withdraw" ]

              else
                text ""
            ]
        , Table.td [] [ Button.button [ Button.primary, Button.onClick <| ViewStandingOrder so.id ] [ text "View" ] ]
        ]


pageStandingOrderPending : Model -> List (Html Msg)
pageStandingOrderPending model =
    List.concat
        [ [ h4 [] [ text "Pending Standing Orders" ]
          , Table.table
                { options = [ Table.striped, Table.hover ]
                , thead =
                    Table.simpleThead
                        [ Table.th [] [ text "Start Date" ]
                        , Table.th [] [ text "Stop Date" ]
                        , Table.th [] [ text "Parties" ]
                        , Table.th [] [ text "TGs" ]
                        , Table.th [] [ text "Frequency" ]
                        , Table.th [] [ text "Status" ]
                        , Table.th [] [ text "" ]
                        , Table.th [] [ text "" ]
                        , Table.th [] [ text "" ]
                        , Table.th [] [ text "" ]
                        ]
                , tbody =
                    Table.tbody []
                        (List.map
                            (pendingStandingOrderSummary model)
                            model.pendingStandingOrders
                        )
                }
          , Html.br [] []
          ]
        , StandingOrderExisting.standingOrderDetailedSummary model model.pendingStandingOrders
        , [ Html.br [] []
          , Html.br [] []
          , Html.br [] []
          , Html.br [] []
          ]
        ]



-- HTTP


acceptStandingOrder : Model -> Int -> Cmd Msg
acceptStandingOrder model txId =
    Http.request
        { method = "PATCH"
        , url = "/api/standing_orders/" ++ String.fromInt txId ++ "/accept"
        , expect = Http.expectJson AcceptedStandingOrder apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


rejectStandingOrder : Model -> Int -> Cmd Msg
rejectStandingOrder model soId =
    Http.request
        { method = "PATCH"
        , url = "/api/standing_orders/" ++ String.fromInt soId ++ "/reject"
        , expect = Http.expectJson RejectedStandingOrder apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


withdrawStandingOrder : Model -> Int -> Cmd Msg
withdrawStandingOrder model soId =
    Http.request
        { method = "DELETE"
        , url = "/api/standing_orders/" ++ String.fromInt soId
        , expect = Http.expectJson StandingOrderDeleted apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
