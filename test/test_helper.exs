ExUnit.start()

{:ok, _} = Flock.MockDiscovery.start_link()
{:ok, _s} = Flock.MockSupervisor.start_link([])