defmodule GiTF.Web.ErrorJSON do
  def render(template, _assigns) do
    %{errors: %{detail: "Error: #{template}"}}
  end
end
