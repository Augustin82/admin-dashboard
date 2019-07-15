module Router exposing
  ( Model
  , Msg(..)
  , init
  , transitionTrigger
  , update
  , view
  )


import Html as Html exposing (..)
import Browser
import Browser.Navigation as Nav
import RemoteData
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, oneOf, s, int, (</>))



import Routes.Home as Home
import Routes.Dash as Dash 
import Session
import SharedState exposing (SharedState, SharedStateUpdate)



{-
Once the application gets more complex,
you can import the models from various routes

import Routes.Home as Home
import Routes.Settings as Settings

type alias Model =
  { home     : Home.Model
  , settings : Settings.Model
  , .....
  , route    : Route
  }
-}


{--
Would be nice if it could be modeled like this:

( Home, HomeModel )
( Dash, DashModel )
( Site, SiteModel )
( NotFound, () )
--}
type alias Model =
  { homeModel  : Home.Model
  , dashModel  : Dash.Model
  , route      : Route
  }

type Route
  = Home
  | Dash
  | Site Int
  | NotFound


type Msg
  = UrlChange Url
  | HomeMsg Home.Msg
  | DashMsg Dash.Msg


parser : Parser (Route -> a) a
parser =
  oneOf
    [ Parser.map Home Parser.top
    , Parser.map Dash (s "dash")
    , Parser.map Site (s "sites" </> int)
    ]

fromUrl : Url -> Route
fromUrl = Maybe.withDefault NotFound << Parser.parse parser


init : Url -> SharedState -> ( Model, Cmd Msg )
init url sharedState =
  let
    route = fromUrl url

  in
  ( { homeModel = Home.init
    , dashModel = Dash.init
    , route     = route
    }
  , transitionTrigger route sharedState
  )



-- trigger commands on page transitions
-- and initializations
transitionTrigger : Route -> SharedState -> Cmd Msg
transitionTrigger route { session, api, navKey } =
  case session of
    RemoteData.Success userSession ->
      case ( route, userSession ) of
        ( Dash, (Session.Admin ( _, token )) ) ->
          Cmd.map DashMsg <| Dash.initRoute token api navKey

        -- redirect guests on private routes
        ( Dash, Session.Guest ) ->
          Nav.pushUrl navKey "/"

        ( Site _, Session.Guest ) ->
          Nav.pushUrl navKey "/"
        
        _ -> Cmd.none

    _ ->
      Cmd.none



update : SharedState -> Msg -> Model -> ( Model, Cmd Msg, SharedStateUpdate )
update state msg model =
  case msg of
    UrlChange url -> 
      let
        route = fromUrl url

        transitionTriggerMsg = transitionTrigger route state

      in
      ( { model | route = route }
      , transitionTriggerMsg
      , SharedState.NoUpdate
      )
      
    HomeMsg homeMsg ->
      let 
        ( homeModel, homeCmd, sharedStateUpdate ) =
          Home.update state homeMsg model.homeModel
      in
        ( { model
            | homeModel = homeModel
          }
        , Cmd.map HomeMsg homeCmd
        , sharedStateUpdate
        )

    DashMsg dashMsg ->
      let
        ( dashModel, dashCmd, sharedStateUpdate ) =
          Dash.update state dashMsg model.dashModel
      in
      ( { model
          | dashModel = dashModel
        }
      , Cmd.map DashMsg dashCmd
      , sharedStateUpdate
      )



view : (Msg -> msg) -> SharedState -> Model -> Browser.Document msg
view toMsg sharedState routerModel =
  let
    ( title, html ) =
      case routerModel.route of
        Home ->
          Home.view sharedState.session routerModel.homeModel
          |> Tuple.mapSecond (Html.map HomeMsg)
          |> Tuple.mapSecond (Html.map toMsg)
          

        Dash ->
          case sharedState.session of
            RemoteData.Success Session.Guest ->
              ( "Redirecting ..."
              , div [] [ text "Redirecting ..."]
              )
            
            RemoteData.Success (Session.Admin ( admin, _ )) -> 
              Dash.view sharedState admin routerModel.dashModel
              |> Tuple.mapSecond (Html.map DashMsg)
              |> Tuple.mapSecond (Html.map toMsg)

            _ ->
              ( "Loading ..."
              , div [] [ text "Loading ..."]
              )

        Site siteId ->
          ( "Site: " ++ (String.fromInt siteId)
          , div [ ] [ text "yey" ]
          )

        NotFound ->
          ( "Woops!", div [] [ text "404 Not Found"] )

  in
  { title = title ++ " | Parlez-Vous "
  , body = [ html ]
  }