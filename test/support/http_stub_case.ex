defmodule HttpStub.Case do
  use ExUnit.CaseTemplate

  setup _ do
    Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
    :ok
  end
end
