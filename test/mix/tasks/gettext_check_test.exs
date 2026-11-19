defmodule Mix.Tasks.Gettext.CheckTest do
  use ExUnit.Case

  alias Mix.Tasks.Gettext.Check

  @moduletag :tmp_dir

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Quiet)
    on_exit(fn -> Mix.shell(shell) end)
  end

  @header ~s(msgid ""\nmsgstr ""\n"Language: en\\n"\n\n)

  defp write_po(tmp_dir, body) do
    path = Path.join(tmp_dir, "en/LC_MESSAGES/test.po")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, @header <> body)
    write_pot(tmp_dir, "")
    path
  end

  defp write_pot(tmp_dir, body) do
    File.write!(Path.join(tmp_dir, "test.pot"), @header <> body)
  end

  test "passes when all msgstrs are filled", %{tmp_dir: tmp_dir} do
    path =
      write_po(tmp_dir, """
      msgid "hello"
      msgstr "hello"

      msgid "one"
      msgid_plural "many"
      msgstr[0] "one"
      msgstr[1] "many"
      """)

    assert :ok = Check.run([path])
  end

  test "passes for multiline msgstrs and obsolete entries", %{tmp_dir: tmp_dir} do
    path =
      write_po(tmp_dir, """
      msgid "hello"
      msgstr ""
      "hello"

      #~ msgid "old"
      #~ msgstr ""
      """)

    assert :ok = Check.run([path])
  end

  test "fails on an empty singular msgstr", %{tmp_dir: tmp_dir} do
    path = write_po(tmp_dir, ~s(msgid "hello"\nmsgstr ""\n))

    error = assert_raise Mix.Error, fn -> Check.run([path]) end
    assert error.message =~ ~s("hello")
    assert error.message =~ path
    assert error.message =~ "mix gettext.update"
  end

  test "fails on an empty plural form", %{tmp_dir: tmp_dir} do
    path =
      write_po(tmp_dir, """
      msgid "one"
      msgid_plural "many"
      msgstr[0] "one"
      msgstr[1] ""
      """)

    assert_raise Mix.Error, ~r/"one"/, fn -> Check.run([path]) end
  end

  test "passes when the POT template matches", %{tmp_dir: tmp_dir} do
    path = write_po(tmp_dir, ~s(msgid "hello"\nmsgstr "hello"\n))
    write_pot(tmp_dir, ~s(msgid "hello"\nmsgstr ""\n))

    assert :ok = Check.run([path])
  end

  test "fails on a POT entry missing from the PO file", %{tmp_dir: tmp_dir} do
    path = write_po(tmp_dir, ~s(msgid "hello"\nmsgstr "hello"\n))

    write_pot(tmp_dir, """
    msgid "hello"
    msgstr ""

    msgid "goodbye"
    msgstr ""

    msgctxt "greeting"
    msgid "hello"
    msgstr ""
    """)

    error = assert_raise Mix.Error, fn -> Check.run([path]) end
    assert error.message =~ ~s(missing "goodbye")
    assert error.message =~ ~s(missing "hello")
    refute error.message =~ "empty msgstr"
    assert error.message =~ "mix gettext.update"
  end

  test "fails when the POT file is missing", %{tmp_dir: tmp_dir} do
    path = write_po(tmp_dir, ~s(msgid "hello"\nmsgstr "hello"\n))
    File.rm!(Path.join(tmp_dir, "test.pot"))

    error = assert_raise Mix.Error, fn -> Check.run([path]) end
    assert error.message =~ "missing POT file"
    assert error.message =~ Path.join(tmp_dir, "test.pot")
    assert error.message =~ "mix gettext.update"
  end

  test "ignores obsolete POT entries", %{tmp_dir: tmp_dir} do
    path = write_po(tmp_dir, ~s(msgid "hello"\nmsgstr "hello"\n))

    write_pot(tmp_dir, """
    msgid "hello"
    msgstr ""

    #~ msgid "old"
    #~ msgstr ""
    """)

    assert :ok = Check.run([path])
  end

  test "passes for the repository's English PO files" do
    assert :ok = Check.run([])
  end
end
