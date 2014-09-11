# An **AgentSet** is an array, along with a class, agentClass, whose instances
# are the items of the array.  Instances of the class are created
# by the `create` factory method of an AgentSet.
#
# It is a subclass of `Array` and is the base class for
# `Patches`, `Agents`, and `Links`. An AgentSet keeps track of all
# its created instances.  It also provides, much like the **ABM.util**
# module, many methods shared by all subclasses of AgentSet.
#
# A model contains three agentsets:
#
# * `patches`: the model's "world" grid
# * `agents`: the model's agents living on the patches
# * `links`: the network links connecting agent pairs
#
# See NetLogo [documentation](http://ccl.northwestern.edu/netlogo/docs/)
# for explanation of the overall semantics of Agent Based Modeling
# used by AgentSets as well as Patches, Agents, and Links.
#
# Note: subclassing `Array` can be dangerous and we may have to convert
# to a different style. See Trevor Burnham's [comments](http://goo.gl/Lca8g)
# but thus far we've resolved all related problems.
#
# Because we are an array subset, @[i] == this[i] == agentset[i]

class ABM.AgentSet extends Array 
# ### Static members
  
  # `asSet` is a static wrapper function converting an array of agents into
  # an `AgentSet` .. except for the ID which only impacts the add method.
  # It is primarily used to turn a comprehension into an AgentSet instance
  # which then gains access to all the methods below.  Ex:
  #
  #     evens = (a for a in @model.agents when a.id % 2 is 0)
  #     ABM.AgentSet.asSet(evens)
  #     randomEven = evens.oneOf()
  @asSet: (a, setType = ABM.AgentSet) ->
    a.__proto__ = setType.prototype ? setType.constructor.prototype # setType.__proto__
    a

  
  # In the examples below, we'll use an array of primitive agent objects
  # with three fields: id, x, y.
  #
  #     AS = for i in [1..5] # long form comprehension
  #       {id:i, x:u.randomInt(10), y:u.randomInt(10)}
  #     ABM.AgentSet.asSet AS # Convert AS to AgentSet in place
  #        [{id:1,x:0,y:1}, {id:2,x:8,y:0}, {id:3,x:6,y:4},
  #         {id:4,x:1,y:3}, {id:5,x:1,y:1}]

# ### Constructor and add/remove agents.
  
  # Create an empty `AgentSet` and initialize the `ID` counter for add().
  # If mainSet is supplied, the new agentset is a sub-array of mainSet.
  # This sub-array feature is how breeds are managed, see class `Model`
  constructor: (@agentClass, @name, @mainSet) ->
    super(0) # doesn't yield empty array if already instances in the mainSet
    @breeds = [] unless @mainSet?
    @agentClass::breed = @ # let the breed know I'm it's agentSet
    @ownVariables = [] # keep list of user variables
    @ID = 0 unless @mainSet? # Do not set ID if I'm a subset

  # Abstract method used by subclasses to create and add their instances.
  create: ->
    
  # Add an agent to the list.  Only used by agentset factory methods. Adds
  # the `id` property to all agents. Increment `ID`.
  # Returns the object for chaining. The set will be sorted by `id`.
  #
  # By "agent" we mean an instance of `Patch`, `Agent` and `Link` and their breeds
  add: (o) ->
    if @mainSet? then @mainSet.add o else o.id = @ID++
    @push o; o

  # Remove an agent from the agentset, returning the agentset.
  # Note this does not change ID, thus an
  # agentset can have gaps in terms of their ids. Assumes set is
  # sorted by `id`. If the set is one created by `asSet`, and the original
  # array is unsorted, simply call `sortById` first, see `sortById` below.
  #
  #     AS.remove(AS[3]) # [{id:0,x:0,y:1}, {id:1,x:8,y:0},
  #                         {id:2,x:6,y:4}, {id:4,x:1,y:1}] 
  remove: (o) ->
    u.removeItem @mainSet, o if @mainSet?
    u.removeItem @, o
    @

  # Set the default value of an agent class, return agentset
  setDefault: (name, value) -> @agentClass::[name] = value; @
  # Declare variables of an agent class. 
  # Vars = a string of space separated names or an array of name strings
  # Return agentset.
  own: (vars) -> # maybe not set default if val is null?
    # vars = vars.split(" ") if not u.isArray vars
    # for name in vars#.split(" ") # if not u.isArray vars
    for name in vars.split(" ")
      @setDefault name, null
      @ownVariables.push name
    @

  # Move an agent from its AgentSet/breed to be in this AgentSet/breed.
  # REMIND: match NetLogo sematics in terms of own variables.
  setBreed: (a) -> # change agent a to be in this breed
    u.removeItem a.breed, a, "id" if a.breed.mainSet?
    u.insertItem @, a, "id" if @mainSet?
    proto = a.__proto__ = @agentClass.prototype
    delete a[k] for own k,v of a when proto[k]?
    a

  # Return all agents that are not of the given breeds argument.
  # Breeds is a string of space separated names:
  #   @patches.exclude "roads houses"
  exclude: (breeds) ->
    breeds = breeds.split(" ")
    @asSet (o for o in @ when o.breed.name not in breeds)

  # Floodfill arguments:
  #
  # * aset: initial array of agents, often a single agent: [a]
  # * fCandidate(a, asetLast) -> true if a is elegible to be added to the set
  # * fJoin(a, asetLast) -> adds a to the agentset, usually by setting a variable
  # * fCallback(asetLast, asetNext) -> optional function to be called each iteration of floodfill;
  # if fCallback returns true, the flood is aborted
  # * fNeighbors(a) -> returns the neighbors of this agent
  # * asetLast: the array of the last set of agents to join the flood;
  # gets passed into fJoin, fCandidate, and fCallback
  floodFill: (aset, fCandidate, fJoin, fCallback, fNeighbors, asetLast=[]) ->
    floodFunc = @floodFillOnce(aset, fCandidate, fJoin, fCallback, fNeighbors, asetLast)
    floodFunc = floodFunc() while floodFunc

  # Move one step forward in a floodfill. floodFillOnce() returns a function that performs the next step of the flood.
  # This is useful if you want to watch your flood progress as an animation.
  floodFillOnce: (aset, fCandidate, fJoin, fCallback, fNeighbors, asetLast=[]) ->
    fJoin p, asetLast for p in aset
    asetNext = []
    for p in aset
      for n in fNeighbors(p) when fCandidate n, aset
        asetNext.push n if asetNext.indexOf(n) < 0
    stopEarly = fCallback and fCallback(aset, asetNext)
    if stopEarly or asetNext.length is 0 then return null
    else return () =>
      @floodFillOnce asetNext, fCandidate, fJoin, fCallback, fNeighbors, aset
  
  # Remove adjacent duplicates, by reference, in a sorted agentset.
  # Use `sortById` first if agentset not sorted.
  #
  #     as = (AS.oneOf() for i in [1..4]) # 4 random agents w/ dups
  #     ABM.AgentSet.asSet as # [{id:1,x:8,y:0}, {id:0,x:0,y:1},
  #                              {id:0,x:0,y:1}, {id:2,x:6,y:4}]
  #     as.sortById().uniq() # [{id:0,x:0,y:1}, {id:1,x:8,y:0}, 
  #                             {id:2,x:6,y:4}]
  uniq: -> u.uniq(@)

  # The static `ABM.AgentSet.asSet` as a method.
  # Used by agentset methods creating new agentsets.
  asSet: (a, setType = @) -> ABM.AgentSet.asSet a, setType # setType = ABM.AgentSet

  # Similar to above but sorted via `id`.
  asOrderedSet: (a) -> @asSet(a).sortById()

  # Return string representative of agentset.
  toString: -> "["+(a.toString() for a in @).join(", ")+"]"

# ### Property Utilities
# Property access, also useful for debugging<br>
  
  # Return an array of a property of the agentset
  #
  #      AS.getProp "x" # [0, 8, 6, 1, 1]
  getProp: (prop) -> ABM.util.aProp(@, prop)

  # Return an array of agents with the property equal to the given value
  #
  #     AS.getPropWith "x", 1
  #     [{id:4,x:1,y:3},{id:5,x:1,y:1}]
  getPropWith: (prop, value) -> @asSet (o for o in @ when o[prop] is value)

  # Set the property of the agents to a given value.  If value
  # is an array, its values will be used, indexed by agentSet's index.
  # This is generally used via: getProp, modify results, setProp
  #
  #     # increment x for agents with x=1
  #     AS1 = ABM.AgentSet.asSet AS.getPropWith("x",1)
  #     AS1.setProp "x", 2 # {id:4,x:2,y:3},{id:5,x:2,y:1}
  #
  # Note this changes the last two objects in the original AS above
  setProp: (prop, value) ->
    if u.isArray value
    then o[prop] = value[i] for o,i in @; @
    else o[prop] = value for o in @; @
  
  # Get the agent with the min/max prop value in the agentset
  #
  #     min = AS.minProp "y"  # 0
  #     max = AS.maxProp "y"  # 4
  maxProp: (prop) -> u.aMax @getProp(prop)
  minProp: (prop) -> u.aMin @getProp(prop)
  histOfProp: (prop, bin=1) -> u.histOf @, bin, prop
  
# ### Array Utilities, often from ABM.util

  # Randomize the agentset
  #
  #     AS.shuffle(); AS.getProp "id" # [3, 2, 1, 4, 5] 
  shuffle: -> u.shuffle @

  # Sort the agentset by the agent's `id`.
  #
  #     AS.shuffle();  AS.getProp "id"  # [3, 2, 1, 4, 5] 
  #     AS.sortById(); AS.getProp "id"  # [1, 2, 3, 4, 5]
  sortById: -> u.sortBy @, "id"

  # Make a copy of an agentset, return as new agentset.<br>
  # NOTE: does *not* duplicate the objects, simply creates a new agentset
  # with references to the same agents.  Ex: create a randomized version of AS
  # but without mangling AS itself:
  #
  #     as = AS.clone().shuffle()
  #     AS.getProp "id"  # [1, 2, 3, 4, 5]
  #     as.getProp "id"  # [2, 4, 0, 1, 3]
  clone: -> @asSet u.clone @

  # Return the last agent in the agentset
  #
  #     AS.last().id             # l5
  #     l=AS.last(); p=[l.x,l.y] # [1,1]
  last: -> u.last @

  # Returns true if the agentset has any agents
  #
  #     AS.any()  # true
  #     AS.getPropWith("x", 99).any() #false
  any: -> u.any @

  # Return an agentset without given agent a
  #
  #     as = AS.clone().other(AS[0])
  #     as.getProp "id"  # [1, 2, 3, 4] 
  other: (a) -> @asSet (o for o in @ when o isnt a) # could clone & remove

  # Return random agent in agentset
  #
  #     AS.oneOf()  # {id:2,x:6,y:4}
  oneOf: -> u.oneOf @

  # Return agentset made of n distinct agents
  #
  #     AS.nOf(3) # [{id:0,x:0,y:1}, {id:4,x:1,y:1}, {id:1,x:8,y:0}]
  nOf: (n) -> @asSet u.nOf @, n

  # Return agent when f(o) min/max in agentset. If multiple agents have
  # min/max value, return the first. Error if agentset empty.
  # If f is a string, return element with min/max value of that property.
  # If "valueToo" then return an array of the agent and the value.
  # 
  #     AS.minOneOf("x") # {id:0,x:0,y:1}
  #     AS.maxOneOf((a)->a.x+a.y, true) # {id:2,x:6,y:4},10 
  minOneOf: (f, valueToo=false) -> u.minOneOf @, f, valueToo
  maxOneOf: (f, valueToo=false) -> u.maxOneOf @, f, valueToo

# ### Drawing
  
  # For agentsets who's agents have a `draw` method.
  # Clears the graphics context (transparent), then
  # calls each agent's draw(ctx) method.
  draw: (ctx) -> 
    u.clearCtx(ctx); o.draw(ctx) for o in @ when not o.hidden; null
  
  # Show/Hide all of an agentset or breed.
  # To show/hide an individual object, set its prototype: o.hidden = bool
  show: -> o.hidden = false for o in @; @draw(@model.contexts[@name])
  hide: -> o.hidden = true for o in @; @draw(@model.contexts[@name])

# ### Topology
  
  # For patches & agents, which have x,y. See ABM.util doc.
  #
  # Return all agents in agentset within d distance from given object.
  # By default excludes the given object. Uses linear/torus distance
  # depending on patches.isTorus, and patches width/height if needed.
  inRadius: (o, d, meToo=false) -> # for any objects w/ x,y
    d2 = d*d; x=o.x; y=o.y
    if @model.patches.isTorus
      w=@model.patches.numX; h=@model.patches.numY
      @asSet (a for a in @ when \
        u.torusSqDistance(x,y,a.x,a.y,w,h)<=d2 and (meToo or a isnt o))
    else
      @asSet (a for a in @ when \
        u.sqDistance(x,y,a.x,a.y)<=d2 and (meToo or a isnt o))
  # As above, but also limited to the angle `cone` around
  # a `heading` from object `o`.
  inCone: (o, heading, cone, radius, meToo=false) ->
    rSet = @inRadius o, radius, meToo
    x=o.x; y=o.y
    if @model.patches.isTorus
      w=@model.patches.numX; h=@model.patches.numY
      @asSet (a for a in rSet when \
        (a is o and meToo) or u.inTorusCone(heading,cone,radius,x,y,a.x,a.y,w,h))
    else
      @asSet (a for a in rSet when \
        (a is o and meToo) or u.inCone(heading,cone,radius,x,y,a.x,a.y))    

# ### Debugging
  
  # Useful in console.
  # Also see [CoffeeConsole](http://goo.gl/1i7bd) Chrome extension.
  
  # Similar to NetLogo ask & with operators.
  # Allows functions as strings. Use:
  #
  #     AS.getProp("x") # [1, 8, 6, 2, 2]
  #     AS.with("o.x<5").ask("o.x=o.x+1")
  #     AS.getProp("x") # [2, 8, 6, 3, 3]
  #
  #     myModel.agents.with("o.id<100").ask("o.color=[255,0,0]")
  ask: (f) -> 
    eval("f=function(o){return "+f+";}") if u.isString f
    f(o) for o in @; @
  with: (f) -> 
    eval("f=function(o){return "+f+";}") if u.isString f
    @asSet (o for o in @ when f(o))

# The example agentset AS used in the code fragments was made like this,
# slightly more useful than shown above due to the toString method.
#
#     class XY
#       constructor: (@x,@y) ->
#       toString: -> "{id:#{@id},x:#{@x},y:#{@y}}"
#     @AS = new ABM.AgentSet # @ => global name space
#
# The result of 
#
#     AS.add new XY(u.randomInt(10), u.randomInt(10)) for i in [1..5]
#
# random run, captured so we can reuse.
#
#     AS.add new XY(pt...) for pt in [[0,1],[8,0],[6,4],[1,3],[1,1]]
