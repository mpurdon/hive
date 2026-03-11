defmodule GiTF.Plugin do
  @moduledoc """
  Plugin DSL macro. Use `use GiTF.Plugin, type: :model` to declare a plugin.

  Automatically sets the behaviour module and provides helper functions
  for registration with the Plugin Manager.
  """

  defmacro __using__(opts) do
    type = Keyword.fetch!(opts, :type)
    behaviour = behaviour_for(type)

    quote do
      @behaviour unquote(behaviour)

      @doc false
      def __plugin_type__, do: unquote(type)

      @doc false
      def __plugin_behaviour__, do: unquote(behaviour)

      defoverridable []
    end
  end

  @doc false
  def behaviour_for(:model), do: GiTF.Plugin.Model
  def behaviour_for(:theme), do: GiTF.Plugin.Theme
  def behaviour_for(:command), do: GiTF.Plugin.Command
  def behaviour_for(:lsp), do: GiTF.Plugin.LSP
  def behaviour_for(:mcp), do: GiTF.Plugin.MCP
  def behaviour_for(:channel), do: GiTF.Plugin.Channel
  def behaviour_for(:tool_provider), do: GiTF.Plugin.ToolProvider
end
