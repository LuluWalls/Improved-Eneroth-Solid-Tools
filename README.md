# Improved-Eneroth-Solid-Tools
An updated version of eneroth-solid-tools: https://github.com/Eneroth3/Eneroth-Solid-Tools by me.

I'm fairly certain the new solid tools work in the same manner as the Julia's origial design. We have of course 'fixed' many of the shortcomings of the earlier algorithms, but not all. And,  there continue to be issues with tiny faces.

Tested with Sketchup versions 8, 2015, and 2017

## About the new Multi-Subtract tool ![Alt text](src/imp_ene_solids/images/cursor_multisub.png?raw=true "Title")
The multi-subtract tool is similar to the original tools but differs in that it allows the user to select multiple objects to be 'cut' with a secondary object.

## To use the Multi-Subtract tool
Select zero, one or more solids,  'the primary collection'.
 
Click the multi-subtract toolbar button ![Alt text](src/imp_ene_solids/images/cursor_multisub.png?raw=true "Title")
 - ![Alt text](src/imp_ene_solids/images/cursor_multisub_plus.png?raw=true "Title")add to the primary collection by holding down the Alt/Option on Mac, Ctrl on PC while clicking on an object
 - ![Alt text](src/imp_ene_solids/images/cursor_multisub_plus_minus.png?raw=true "Title")add or subtract to/from the primary collection by holding down the Shift key while clicking on an object
 - ![Alt text](src/imp_ene_solids/images/cursor_multisub_primary.png?raw=true "Title")choose the first item to add to the primary collection
 - control-A to add everything to the primary collection
 
Click on the secondary object to perform the subtraction ![Alt text](src/imp_ene_solids/images/cursor_multisub_secondary.png?raw=true "Title")

The cursor will change to indicate which of the above operations the tool is expecting

It is also possible to Swap the primary and secondary by holding down Command on Mac, Alt on PC when you click the secondary
 
To change the preferences you must activate the Multi-Subtract tool and right click with the mouse.

The options are:

![Alt text](src/imp_ene_solids/images/example_options2.png?raw=true "Title")

 - Cut Subcomponents, not just the top level components
 - Hide the secondary object after subtraction
 - Texture the new faces (with a default Dark Grey material named 'Ene_Cut_Face_Color')
 - Make each subcomponent a unique object
 
 ## An Example
  ![Alt text](src/imp_ene_solids/images/demo.gif?raw=true "Title")
  
 
 
 
Hey Lulu, why would you go to all of this trouble?
 
 Well, I wanted to make a presentation like this
 
 
  ![Alt text](src/imp_ene_solids/images/timber_slice.jpg?raw=true "Title")

 
