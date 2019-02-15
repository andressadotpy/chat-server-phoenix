# Learn Elixir and Phoenix by building things

[Alchemist Camp](https://alchemist.camp/episodes/phoenix-1.4-chat-intro) - Phoenix 1.4 Chat Server  

## Part 1

Create new project:  
$ mix phx.new  
Create database  
$ mix ecto.create  
Running server  
$ iex -S mix phx.server  

### webpack.config.js

- Change to run sccs and css files  

      {  
        test: /\.s?css$/,  
        use: [MiniCssExtractPlugin.loader, 'css-loader', 'sass-loader']  
      }  


inside /assets/js/app.js change to import add.scss  

install loaders  

$ cd assets  

$ npm install --save-dev node-sass sass-loader
(adiciona sass em package.json)  

- Change extension of /assets/css/app.css to app.scss

## Part 2

- Using Phoenix Generators to create all of the cruds for users and users credentials and chat rooms  

Context: Accounts | User: Schema | users: table name  
$ mix phx.gen.html Accounts User users name username:unique  
(don't need to specify name:string username:string)  

Context: Accounts | Credential: Schema | credentials: table name  
$ mix phx.gen.context Accounts Credential credentials email:unique password_hash user_id:references:users  

Context: Chat | Room: Schema | rooms: table name  
$ mix phx.gen.html Chat Room rooms name:unique description:text user_id:references:users  

add to router (lib/chit_chat_web/router.ex):  

resources "/rooms", RoomController  
resources "/users", UserController  

...  
  scope "/", ChitChatWeb do  
    pipe_through :browser  

    get "/", PageController, :index  
    resources "/rooms", RoomController  
    resources "/users", UserController  
  end  
...  

- Modifying lib/chit_chat/accounts/user.ex

alias Comeonin.Argon2  

- password and password_confirmation are equals and virtuals; only password_hash is saved at the database 
  schema "credentials" do  
    field :email, :string  
    field :password_hash, :string  
    field :password, :string, virtual: true  
    field :password_confirmation, :string, virtual: true  
    belongs_to :user, ChitChat.Accounts.User  

    timestamps()  
  end  

- Verify if email is valid and unique  
  def changeset(credential, attrs) do  
    credential  
    |> cast(attrs, [:email])  
    |> validate_required([:email])  
    |> validate_format(:email, ~r/@/)  
    |> unique_constraint(:email)  
  end  

- Verify if password is valid and if password and password_confirmation are the same  
  def registration_changeset(struct, attrs // %{}) do  
      struct  
      |> changeset(attrs)  
      |> cast(attrs, [:password, :password_confirmation])  
      |> validate_required([:password, :password_confirmation])  
      |> validate_length(:password, min: 8)  
      |> validate_confirmation(:password)  
      |> hash_password()  
  end  

- If password it's not valid, calls changeset again
  def hash_password(%{valid?: false} = changeset), do: changeset  

- If password is valid, hash (encrypts) the password to save password_hash on the database  
  def hash_password(%{valid?: true, changes: %{password: pass}} = changeset) do  
      put_change(changeset, :password_hash, Argon2.hashpwsalt(pass))  
  end  

- Comeonin isn't installed by default in Phoenix, so go to mix.exs at top level of the app and add that dependency  


  defp deps do  
    [  
      {:phoenix, "~> 1.4.1"},  
      {:phoenix_pubsub, "~> 1.1"},  
      {:phoenix_ecto, "~> 4.0"},  
      {:ecto_sql, "~> 3.0"},  
      {:postgrex, ">= 0.0.0"},  
      {:phoenix_html, "~> 2.11"},  
      {:phoenix_live_reload, "~> 1.2", only: :dev},  
      {:gettext, "~> 0.11"},  
      {:jason, "~> 1.0"},  
      {:plug_cowboy, "~> 2.0"},  
      {:comeonin, "~> 4.0"},  
      {:argon2_elixir, "~> 1.2"}  
    ]  
  end  

add dependencies:  
$ mix deps.get  

- Modifying lib/chit_chat/accounts/accounts.ex

alias ChitChat.Accounts.{Credential, User}  
import Comeonin.Argon2, only: [checkpw: 2, dummy_checkpw: 0]  

  def get_user!(id) do  
      Repo.get!(User, id)  
      |> Repo.preload(:credential)  
  end  

changeset doesn't create credential alone  

  def create_user(attrs \\ %{}) do  
    %User{}  
    |> User.changeset(attrs)  
    |> Ecto.Changeset.cast_assoc(:credential, with: &Credential.registration_changeset/2)  
    |> Repo.insert()  
  end  

- update user has to deal with two possibilities:
+ if the user wants to change password or if wants to register

  def update_user(%User{} = user, attrs) do  
    cred_changeset =  
        if attrs["credential"]["password"] == "" do  
            &Credential.changeset/2  
        else  
            &Credential.registration_changeset/2  
        end  
    user  
    |> User.changeset(attrs)  
    |> Ecto.Changeset.cast_assoc(:credential, with: cred_changeset)  
    |> Repo.update()  
  end  


- Modifying /lib/chit_chat_web/templates/user/form.html.eex

  <div class="form-group">  
    <%= inputs_for f, :credential, fn cf -> %>  
      <%= label cf, :email %>  
      <%= text_input cf, :email %>  
      <%= error_tag cf, :email %>  

      <%= label cf, :password %>  
      <%= password_input cf, :password %>  
      <%= error_tag cf, :password %>  

      <%= label cf, :password_confirmation %>  
      <%= password_input cf, :password_confirmation %>  
      <%= error_tag cf, :password_confirmation %>  
    <% end %>  
  </div>  

$ iex -S mix phx.server  
(iex) alias ChitChat.Accounts  
(iex) Accouts.list_users  

[debug] QUERY OK source="users" db=1.5ms queue=0.1ms
SELECT u0."id", u0."name", u0."username", u0."inserted_at", u0."updated_at" FROM "users" AS u0 []

(iex) Accounts.get_user! 1
[debug] QUERY OK source="credentials" db=2.0ms
SELECT c0."id", c0."email", c0."password_hash", c0."user_id", c0."inserted_at", c0."updated_at", c0."user_id" FROM "credentials" AS c0 WHERE (c0."user_id" = $1) [1]

## Part 3

### Making Sessions

- Modifying /lib/chit_chat_web/router.ex

    resources "/sessions", SessionController, only: [:new, :create, :delete], singleton: true

    get "/login", SessionController, :new  
    get "/logout", SessionController, :delete

- Create SessionController
/lib/chit_chat_web/controllers   
new file: session_controller.ex  

- Create view
/lib/chit_chat_web/views  
new file: session_view.ex  

defmodule ChitChatWeb.SessionView do  
  use ChitChatWeb, :view  
end  

- Create template
/lib/chit_chat_web/templates  
create new directory named session  
create new file in the session directory called new.html.eex  

- Create inside accounts.ex a function authenticate_by_email_password to check if email and password matches

- Call authenticate_by_email_password inside the function create in session_controller.ex 

## Part 4

### Authentication

add plug in /lib/views/router.ex ChitChat.Auth

create a new directory called plugs inside chit_chat_web

create a new file inside plugs called auth.ex and defmodule ChitChat.Auth

defmodule ChitChat.Auth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && ChitChat.Accounts.get_user!(user_id)
    assign(conn, :current_user, user)
  end
end


modifying the layout with

User ID: <%= @current_user.name %>  
puts name of the current user at the page

User ID: <%= @current_user.id %>  
puts id of the current user at the page

https://github.com/smpallen99/ex_admin/issues/117
