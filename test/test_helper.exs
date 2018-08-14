ExUnit.start()

{:ok, _} = Herd.MockDiscovery.start_link()
{:ok, _s} = Herd.MockSupervisor.start_link([])