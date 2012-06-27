TOFFEE
=========
A templating language based on CoffeeScript with slicker tokens and automatic space sensing. 
Compatible with Express 2.x, 3.x, and the browser. In Express 3.x, the Toffee engine handles partials 
and view caching (with convenient time limits). 

status
======
Beta with lots of bug possibilities. Don't use unless you work at OkCupid 
or don't mind changing syntax.

And there aren't yet meaningful line numbers on errors.

examples
========
Printing variables is easy. Just use CoffeeScript's #{} syntax:
```
<p>Hello, #{user.name}</p>
```

Which of course is very powerful, if you want to get crazy:
```
You have #{(x for x in friends when x.g is "f").length} female friends.
```

But real pleasure arises when switching between `coffee` mode and `toffee` mode:
```
{#
   if @projects.length
    for project in @projects {:
      <a href="#{project.url}">#{project.name}</a>
      <p>#{project.description}</p>
    :}
   else {:No projects:}
#}
```

To enter coffee mode, use a block of this form: `{# ... #}`. Inside a region of coffee,
you can switch back to toffee with `{: ... :}`. This syntax is nestable and avoids a lot of large, ugly regions, such
as `<% end %>`. Compare:

EJS
```
<ul>
<% for(var i=0; i<supplies.length; i++) {%>
   <li><%= supplies[i] %></li>
<% } %>
</ul>
```

TOFFEE
```
<ul>
  {# for supply in supplies {:<li>#{supply}</li>:} #}
</ul>
```


Nesting is a very important part of Toffee. When you're in a `{: toffee :}` block, 
feel free to create a nested '{# coffee #}` block, and indentation is inferred.

```
{#
   for name, info of friends when info.age < 21 {:
      #{name} would make a great designated driver.
      {#
         info.cars.sort (a,b) -> b.speed - a.speed
         if info.cars.length {: And she drives a #{info.cars[0].model} :}
         else                {: But she has no wheels. :}
      #}      
   :}
#}
```

Switching to pub mode without indenting
-----
By default, when you enter `{: ... :}`, the Toffee compiler assumes you're entering an indented region. 
If you ever want to cut into toffee mode without indenting, use `-{: ... :}`. For example:

```
{#
   name = "Chris"
   -{:name:}
#}
```

Questions
========

How does it compare to eco?
--------------------------
Eco is another CoffeeScript templating language. 
The syntaxes are pretty different, so pick the one you prefer. Some examples:

ECO
```
<% if @projects.length: %>
  <% for project in @projects: %>
    <a href="<%= project.url %>"><%= project.name %></a>
    <p><%= project.description %></p>
  <% end %>
<% else: %>
  No projects
<% end %>
```

TOFFEE
```
{#
   if @projects.length
    for project in @projects {:
      <a href="#{project.url}">#{project.name}</a>
      <p>#{project.description}</p>
    :}
   else {:No projects:}
#}
```

Here's the nested example, from above, in eco.

ECO
```
<% for name, info of friends when info.age < 21 : %>
  <%= name %> would make a great designated driver.
  <% info.cars.sort (a,b) -> b.speed - a.speed %>
  <% if info.cars.length : %> And she drives a <%= info.cars[0].model %>
  <% else: %> But she has no wheels
  <% end %>
<% end %>
```

One nice feature that eco has is auto-escaping output. If you want to escape for HTML, URL's, or JS in Toffee, 
you can do that with a function of your choice.

A note on indentation
-----
Toffee realigns all your coffeescript inside a `{# region #}` by normalizing the indentation of that region.
So it doesn't matter how you indent things, as long as it makes local sense inside that region. For example, these
are all identical:

```
<p>{# if x == 0 {:Yay!:} else  {:Burned:} #}</p>
```

```
<p>{# 
  if x == 0 {:Yay!:} else {:Burned:}
#}</p>
```

```
<p>
{# 
             if x == 0 {:Yay!:}
             else      {:Burned:}
#}</p>
```

However, this would cause an error:

ERROR
```
<p>
{# 
             if x == 0 {:Yay!:}
               else      {:Burned:}
#}</p>
```

As would this more subtle case:

ERROR
```
<p>
{#   if x == 0 {:Yay!:}
     else      {:Burned:}
#}</p>
```

In the above 2 cases, note that the leading whitespaces before the `if` and `else` are different.

Comments
-----
Inside a region of coffee, you can use coffee's `#` or `###` syntax to comment. 
Inside toffee mode, you can comment with `{## ... ##}`.

```
{## This isn't output ##}
But this is.
```


installation & usage
===========
```
npm install -g toffee
```

In Express 3.x to make it your default engine:
```
app.set 'view engine', 'toffee'
```

In Express 3.x to use it just for .toffee files:
```
toffee = require 'toffee'
app.engine 'toffee', toffee.__express
```


Express 2.x:
```
toffee      = require 'toffee'
app.register '.toffee', toffee
```

contributing
=============
I would love for someone to make a textmate/sublime bundle for Toffee. :-) . I would even pay for it.


todo
======
- finish browser-side include and command-line compiler
- ...then add instructions on how to use it
- escapeHTML, JS, etc. functions
- continue to add to unit tests
- better line numbers on errors
