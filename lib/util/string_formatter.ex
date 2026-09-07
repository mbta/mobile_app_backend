defmodule Util.StringFormatter do
  def format_list_for_log(list, max_items) when length(list) > max_items do
    formatted_list = Enum.take(list, max_items)
    Enum.join(formatted_list, ", ") <> "..."
  end

  def format_list_for_log(list, _max_items) do
    Enum.join(list, ", ")
  end
end
