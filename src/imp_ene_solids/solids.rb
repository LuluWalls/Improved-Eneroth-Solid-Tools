# load 'imp_ene_solids/solids.rb'

module Imp_EneSolidTools

  # Various solid operations.
  #
  # To use these operators in your own project, copy the whole class into it
  # and into your own namespace (module).
  #
  # Face orientation is used on touching solids to determine whether faces
  # should be removed or not. Make sure faces are correctly oriented before
  # using.
  #
  # Differences from native solid tools:
  #  * Preserves original Group/ComponentInstance object with its own material,
  #    layer, attributes and other properties instead of creating a new one.
  #  * Preserves primitives inside groups/components with their own layers,
  #    attributes and other properties instead of creating new ones.
  #  * Ignores nested geometry, a house is for instance still a solid you can
  #    cut away a part of even if there's a cut-opening window component in the
  #    wall.
  #  * Operations on components alters all instances as expected instead of
  #    creating a new unique Group (that's what context menu > Make Unique is
  #    for).
  #  * Doesn't break material inheritance. If a Group/ComponentInstance itself
  #    is painted and child faces are not this will stay the same.
  #
  # I, Eneroth3, is much more of a UX person than an algorithm person. Someone
  # who is more of the latter might be able to optimize these operations and
  # make them more stable.
  #
  # If you contribute to the project, please don't mess up these differences
  # from the native solid tools. They are very much intended, and even the
  # reason why this project was started in the first place.
  class Solids
   
=begin    
    # Multi subtract - trim the secondary object from an array of primary objects
    # primary      array of objects to be cut
    # secondary    group or component to cut with 
    # settings    hash:
    #   paint     is Nil or is a material in the model's materials collection
    #   hide
    #   cut_sub   if true, subtract from subcomponents
    #   unique    if true, make target object unique
    # return value is undefined
=end

    def self.multisub(primary, secondary, settings)
      @progress = 'Working |'
      
      #Create material to apply to the cut faces if settings[:paint]
      # I can imagine painting cut faces with cross hatching, etc.
      if settings[:paint]
        model = Sketchup.active_model
        materials = model.materials
        paint = materials['Ene_Cut_Face_Color']
        if !paint
          paint = materials.add('Ene_Cut_Face_Color') 
          #@paint.color = 'red'
          paint.color = 'DimGray'
        end 
      else
        paint = nil      
      end
    # scale = 1000 for the top level, the Dave Method
    multisub_recurse(primary, secondary, scale = 1000, paint, settings[:cut_sub], settings[:unique])
    end

    def self.multisub_recurse(primary, secondary, scale, paint, cut_sub, unique)
      #primary is an array of groups or component instances
      primary.each do |target|
        Sketchup.status_text = @progress
        @progress << '|'
        next if target == secondary # don't cut yourself
        next unless target.bounds.intersect(secondary.bounds) #quick but dirty exclude
        target.make_unique if unique
  
        if !subtract(target, secondary, false, true, scale, paint)  
         # if a primary group/component is totally empty sketchup will mark it as deleted
         # and it will be removed after the model.commit statement in tools.rb
         #puts 'Empty or Not Solid in Solids::multisub'
        end     
        
        # recursuvely subtract from the subcomponents
        next if cut_sub == false
        entities(target).select {|e| [Sketchup::Group, Sketchup::ComponentInstance].include?(e.class)}.each do |child|
          tr_save = child.transformation
          child.transformation = target.transformation * child.transformation
          #cut subcomponents with a scale of 1
          multisub_recurse([child], secondary, 1, paint, cut_sub, unique)
          child.transformation = tr_save 
        end
      end
    end     
 

=begin # Trim one container using another.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance to trim using the
    #                    secondary one.
    # secondary        - The secondary Group/ComponentInstance to trim the
    #                    primary one with.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    #
    # Returns true if result is a solid, false if something went wrong.
=end 
    def self.trim(primary, secondary, wrap_in_operator = true)
      subtract(primary, secondary, wrap_in_operator, true)
    end

    # Subtract one container from another.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance the secondary one
    #                    should be subtracted from.
    # secondary        - The secondary Group/ComponentInstance to subtract from
    #                    the primary one.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    # keep_secondary   - Whether secondary should be left untouched. The same as
    #                    whether operation should be trim instead subtract.
    #                    (default: false)
    #
    # Returns true if result is a solid, false if something went wrong.

    def self.subtract(primary, secondary, wrap_in_operator = true, keep_secondary = false, scale = 1000, paint = nil)
      
      #Check if both groups/components are solid, and that there are edges
      return if !entities(primary).any? { |e| e.is_a?(Sketchup::Edge)} #
      return if !is_solid?(primary) || !is_solid?(secondary)
      op_name = keep_secondary ? "Trim" : "Subtract"
      primary.model.start_operation(op_name, true) if wrap_in_operator

      # Older SU versions doesn't automatically make Groups unique when they are
      # edited.
      # Components on the other hand should off course not be made unique here.
      # That is up to the user to do manually if they want to.
      primary.make_unique if primary.is_a?(Sketchup::Group)

      # scale every thing by 1000
      transP = primary.transformation
      transS = secondary.transformation
      tr = Geom::Transformation.scaling(scale)
      primary.transform!(tr)
      secondary.transform!(tr)
      
      # make a reference copy of the original objects
      # make a copy of the secondary that will be modified
      secondary_reference_copy = primary.parent.entities.add_group
	    secondary_reference_copy.name = 'secondary_reference_copy'
      move_into(secondary_reference_copy, secondary, true)

      secondary_to_modify = primary.parent.entities.add_group
	    secondary_to_modify.name = 'secondary_to_modify'
      move_into(secondary_to_modify, secondary, keep_secondary)
      
      #transform secondary back to original scale if we are keeping it
      secondary.transformation = transS if keep_secondary
      
      primary_reference_copy = primary.parent.entities.add_group
	    primary_reference_copy.name = 'primary_reference_copy'
      move_into(primary_reference_copy, primary, true)

      #grab the entities collections
      primary_ents = entities(primary)
      secondary_ents = entities(secondary_to_modify)

      # intersect A into B, and B into A
      intersect_wrapper(primary, secondary_to_modify)
      
      # Remove faces in primary that are inside the secondary and faces in
      # secondary that are outside primary.
      to_remove = find_faces_inside_outside(primary, secondary_reference_copy, true)
      to_remove1 = find_faces_inside_outside(secondary_to_modify, primary_reference_copy, false)
      secondary_reference_copy.erase!
	    primary_reference_copy.erase!

      # Remove faces that exists in both groups and have opposite orientation.
      corresponding = find_corresponding_faces(primary, secondary_to_modify, true)
      corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
      primary_ents.erase_entities(to_remove)
      secondary_ents.erase_entities(to_remove1)

      # Reverse all faces in secondary
      secondary_ents.each { |f| f.reverse! if f.is_a? Sketchup::Face }
      
      # paint the cut faces if paint defined
      secondary_ents.each {|f| f.material = paint if f.is_a? Sketchup::Face} if paint 
      
      # combine the two objects
      move_into(primary, secondary_to_modify, false)

      # Purge edges not binding 2 faces
      primary_ents.erase_entities(primary_ents.select {|e| e.is_a?(Sketchup::Edge) && e.faces.size < 2})
     
      # Remove co-planar edges
      primary_ents.erase_entities(find_coplanar_edges(primary_ents))
      
      # unscale object
      primary.transformation = transP
      
      primary.model.commit_operation if wrap_in_operator
      is_solid?(primary)
    end

 
=begin    # Unite one container with another.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance the secondary one
    #                    should be added to.
    # secondary        - The secondary Group/ComponentInstance to add to the
    #                    primary one.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    #
    # Returns true if result is a solid, false if something went wrong.
=end
    def self.union(primary, secondary, wrap_in_operator = true)
      #Check if both groups/components are solid.
      return if !is_solid?(primary) || !is_solid?(secondary)
      primary.model.start_operation("Union", true) if wrap_in_operator

      # Older SU versions doesn't automatically make Groups unique when they are
      # edited.
      # Components on the other hand should off course not be made unique here.
      # That is up to the user to do manually if they want to.
      primary.make_unique if primary.is_a?(Sketchup::Group)

      # scale every thing by 1000
      scale = 1000
      transP = primary.transformation
      transS = secondary.transformation
      tr = Geom::Transformation.scaling(scale)
      primary.transform!(tr)
      secondary.transform!(tr)
      
      # make a reference copy of the original objects
      # make a copy of the secondary that will be modified
      secondary_reference_copy = primary.parent.entities.add_group
	    secondary_reference_copy.name = 'secondary_reference_copy'
      move_into(secondary_reference_copy, secondary, true)
      
      secondary_to_modify = primary.parent.entities.add_group
	    secondary_to_modify.name = 'secondary_to_modify'
      move_into(secondary_to_modify, secondary, false)
      
      primary_reference_copy = primary.parent.entities.add_group
	    primary_reference_copy.name = 'primary_reference_copy'
      move_into(primary_reference_copy, primary, true)
      
      #grab the entities collections
      primary_ents = entities(primary)
      secondary_ents = entities(secondary_to_modify)

      # intersect A into B, and B into A
      intersect_wrapper(primary, secondary_to_modify)

      # Remove faces inside primary and inside secondary
      to_remove = find_faces_inside_outside(primary, secondary_reference_copy, true)
      to_remove1 = find_faces_inside_outside(secondary_to_modify, primary_reference_copy, true)
	    secondary_reference_copy.erase!
	    primary_reference_copy.erase!
      
      # Remove faces that exists in both groups and have opposite orientation.
      corresponding = find_corresponding_faces(primary, secondary_to_modify, false)
      corresponding.each_with_index { |v, i| i.even? ? to_remove << v : to_remove1 << v }
      
      primary_ents.erase_entities(to_remove)
      secondary_ents.erase_entities(to_remove1)

      # combine the two objects
      move_into(primary, secondary_to_modify, false)
 
      # Purge edges naked edges
      primary_ents.erase_entities(primary_ents.select {|e| e.is_a?(Sketchup::Edge) && e.faces.size == 0})
 
      # Remove co-planar edges
      primary_ents.erase_entities(find_coplanar_edges(primary_ents))
      
      # unscale object
      primary.transformation = transP
      
      primary.model.commit_operation if wrap_in_operator
      is_solid?(primary)
    end


=begin    # Intersect containers.
    #
    # The primary Group/ComponentInstance keeps its material, layer, attributes
    # and other properties. Primitives inside both containers also keep their
    # materials, layers, attributes and other properties.
    #
    # primary          - The primary Group/ComponentInstance the intersect
    #                    intersect result will be put in.
    # secondary        - The secondary Group/ComponentInstance.
    # wrap_in_operator - True to add an operation so all changes can be undone
    #                    in one step. Set to false when called from custom
    #                    script that already uses an operator. (default: true)
    #
    # Returns true if result is a solid, false if something went wrong.
=end
    def self.intersect(primary, secondary, wrap_in_operator = true)
      #Check if both groups/components are solid.
      return if !is_solid?(primary) || !is_solid?(secondary)
      primary.model.start_operation("Intersect", true) if wrap_in_operator
      
      # Older SU versions doesn't automatically make Groups unique when they are
      # edited.
      # Components on the other hand should off course not be made unique here.
      # That is up to the user to do manually if they want to.
      primary.make_unique if primary.is_a?(Sketchup::Group)

      # scale every thing by 1000
      scale = 1000
      transP = primary.transformation
      transS = secondary.transformation
      tr = Geom::Transformation.scaling(scale)
      primary.transform!(tr)
      secondary.transform!(tr)
      
      # make a reference copy of the original objects
      # make a copy of the secondary that will be modified
      secondary_reference_copy = primary.parent.entities.add_group
	    secondary_reference_copy.name = 'secondary_reference_copy'
      move_into(secondary_reference_copy, secondary, true)

      secondary_to_modify = primary.parent.entities.add_group
	    secondary_to_modify.name = 'secondary_to_modify'
      move_into(secondary_to_modify, secondary, false)
      
      primary_reference_copy = primary.parent.entities.add_group
	    primary_reference_copy.name = 'primary_reference_copy'
      move_into(primary_reference_copy, primary, true)

      #grab the entities collections
      primary_ents = entities(primary)
      secondary_ents = entities(secondary_to_modify)

      # intersect A into B, and B into A
      intersect_wrapper(primary, secondary_to_modify)
  
      # Remove faces in primary that are outside of the secondary
      # and faces in secondary that are outside primary.
      to_remove = find_faces_inside_outside(primary, secondary_reference_copy, false)
      to_remove1 = find_faces_inside_outside(secondary_to_modify, primary_reference_copy, false)
      primary_ents.erase_entities(to_remove)
      secondary_ents.erase_entities(to_remove1)
      
      # done with these!
	    secondary_reference_copy.erase!
	    primary_reference_copy.erase!
	  
      # combine the two objects
      move_into(primary, secondary_to_modify, false)
	  
      # Purge edges not binding 2 faces
      primary_ents.erase_entities(primary_ents.select {|e| e.is_a?(Sketchup::Edge) && e.faces.size < 2})

      # unscale object
      primary.transformation = transP
      
      primary.model.commit_operation if wrap_in_operator
      is_solid?(primary)
    end


    private

    # Internal: Get the Entities object for either a Group or CompnentInstance.
    # SU 2014 and lower doesn't support Group#definition.
    #
    # group_or_component - The group or ComponentInstance object.
    #
    # Returns an Entities object.
    def self.entities(group_or_component)
      if group_or_component.is_a?(Sketchup::Group)
        group_or_component.entities
      else
        group_or_component.definition.entities
      end
    end

    # Internal: Intersect solids and get intersection edges in both solids.
    #
    # ent0 - One of the groups or components to intersect.
    # ent1 - The other groups or components to intersect.
    #
    #Returns nothing.
    def self.intersect_wrapper(ent0, ent1)
      #Intersect twice to get coplanar faces.
      #Copy the intersection geometry to both solids.
      
      ents0 = entities(ent0)
      ents1 = entities(ent1)

      # create a temporary group to hold the result of the intersection
      temp_group = ent0.parent.entities.add_group
      temp_group.name = 'temp_group'

      #Only intersect raw geometry, save time and avoid unwanted edges.
      ents0.intersect_with(false, ent0.transformation, temp_group.entities, IDENTITY, true, ents1.to_a.select { |e| [Sketchup::Face, Sketchup::Edge].include?(e.class) })
      ents1.intersect_with(false, ent0.transformation.inverse, temp_group.entities, ent0.transformation.inverse, true, ents0.to_a.select { |e| [Sketchup::Face, Sketchup::Edge].include?(e.class)})
     
      move_into(ent0, temp_group, true)
      move_into(ent1, temp_group, false)
	  
      # fix missing faces. after an intersect_with or move_into() there may be missing faces
      list = ents0.select { |e| e.is_a?(Sketchup::Edge) && e.faces.size == 0 }
      list.each{|e| e.find_faces}
        
      list = ents1.select { |e| e.is_a?(Sketchup::Edge) && e.faces.size == 0 }
      list.each{|e| e.find_faces}
      

    end

    # Internal: Find arbitrary point inside face, not on its edge or corner.
    # face - The face to find a point in.
    # Returns a Point3d object.
    def self.point_in_face(face)
      # Sometimes invalid faces gets created when intersecting.
      # These are removed when validity check run.
      return if face.area == 0

      # First find centroid and check if is within face (not in a hole).
      centroid = face.bounds.center
      return centroid if face.classify_point(centroid) == Sketchup::Face::PointInside
	
      # Find points by combining 3 adjacent corners.
      # If middle corner is convex point should be inside face (or in a hole).
      face.vertices.each_with_index do |v, i|
        c0 = v.position
        c1 = face.vertices[i-1].position
        c2 = face.vertices[i-2].position
        p  = Geom.linear_combination(0.9, c0, 0.1, c2)
        p  = Geom.linear_combination(0.9, p,  0.1, c1)
        return p if face.classify_point(p) == Sketchup::Face::PointInside
      end
		  warn "Algorithm failed to find an arbitrary point on face."
      nil
    end

   
    # Internal: Find faces that exists with same location in both contexts.
    #
    # same_orientation - true to only return those oriented the same direction,
    #                    false to only return those oriented the opposite
    #                    direction and nil to skip direction check.
    #
    # Returns an array of faces, every second being in each drawing context.
    def self.find_corresponding_faces(ent0, ent1, same_orientation)
      faces = []
      entities(ent0).each do |f0|
        next unless f0.is_a?(Sketchup::Face)
        normal0 = f0.normal.transform(ent0.transformation)
        points0 = f0.vertices.map { |v| v.position.transform(ent0.transformation) }
        entities(ent1).each do |f1|
          next unless f1.is_a?(Sketchup::Face)
          normal1 = f1.normal.transform(ent1.transformation)
          next unless normal0.parallel?(normal1)
          points1 = f1.vertices.map { |v| v.position.transform(ent1.transformation) }
          
          # this was way too simple!!! We needed a two way comparison
          #next unless points0.all? { |v| points1.include?(v) }
          next unless points0.all? { |v| points1.include?(v) } && points1.all? { |v| points0.include?(v) }
          unless same_orientation.nil?
            next if normal0.samedirection?(normal1) != same_orientation
          end
          faces << f0
          faces << f1
        end
      end

      faces
    end

    # Internal: Merges groups/components.
    # Requires both groups/components to be in the same drawing context.
    def self.move_into(destination, to_move, keep = false)
      destination_ents = entities(destination)
      to_move_def = to_move.is_a?(Sketchup::Group) ? to_move.entities.parent : to_move.definition

      trans_target = destination.transformation
      trans_old = to_move.transformation

      trans = trans_old*(trans_target.inverse)
      trans = trans_target.inverse*trans*trans_target

      temp = destination_ents.add_instance(to_move_def, trans)
      to_move.erase! unless keep
      temp.explode
    end
    
    # Internal: Find all co-planar edges
    def self.find_coplanar_edges(ents)
      ents.select do |e|
        next unless e.is_a?(Sketchup::Edge)
        next unless e.faces.size == 2
        e.faces[0].normal == e.faces[1].normal
      end
   end
   
    # Internal: Find faces based on their position relative to the
    # other solid.
    def self.find_faces_inside_outside(source, reference, inside)
	  entities(source).select do |f|
        next unless f.is_a?(Sketchup::Face)
        point = point_in_face(f)
        
        if point
          point.transform!(source.transformation)
          next if inside != inside_solid?(point, reference, !inside)
        #else
          #for tiny faces we can test if any vertex is inside/outside the reference object
          #next unless f.vertices.any? {|v|
            #point = v.position
            #point.transform!(source.transformation)
            #inside != inside_solid?(point, reference, !inside)
          #}
        end
        
	    true
      end
    end

    
    # Check whether Point3d is inside, outside or the surface of solid.
    #
    # point                - Point3d to test (in the coordinate system the
    #                        container lies in, not internal coordinates).
    # container            - Group or component to test point to.
    # on_face_return_value - What to return when point is on face of solid.
    #                        (default: true)
    # verify_solid         - First verify that container actually is
    #                        a solid. (default true)
    #
    # Returns true if point is inside container and false if outside. Returns
    # on_face_return_value when point is on surface itself.
    # Returns nil if container isn't a solid and verify_solid is true.
    #def self.inside_solid?(point, container, on_face_return_value = true)
    def self.inside_solid?(point, container, on_face_return_value)
      #return if verify_solid && !is_solid?(container)

      # Transform point coordinates into the local coordinate system of the
      # container. The original point should be defined relative to the axes of
      # the parent group or component, or, if the user has that drawing context
      # open, the global model axes.
      #
      # All method that return coordinates, e.g. #transformation and #position,
      # returns them local coordinates when the container isn't open and global
      # coordinates when it is. Usually you don't have to think about this but
      # as usual the (undocumented) attempts in the SketchUp API to dumb things
      # down makes it really odd and difficult to understand.
      point = point.transform(container.transformation.inverse)

      # Cast a ray from point in arbitrary direction an check how many times it
      # intersects the mesh.
      # Odd number means it's inside mesh, even means it's outside of it.

      # Use somewhat random vector to reduce risk of ray touching solid without
      # intersecting it.
      vector = Geom::Vector3d.new(234, 1343, 345)
      ray = [point, vector]
	  
      intersection_points = entities(container).map do |face|
        next unless face.is_a?(Sketchup::Face)

		# If point is on face of solid, return value specified for that case.
		clasify_point = face.classify_point(point)
		return on_face_return_value if [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include?(clasify_point)
			
		intersection = Geom.intersect_line_plane(ray, face.plane)
		next unless intersection
		next if intersection == point

		# Intersection must be in the direction ray is casted to count.
		next unless (intersection - point).samedirection?(vector)

		# Check intersection's relation to face.
		# Counts as intersection if on face, including where cut-opening component cuts it.
		classify_intersection = face.classify_point(intersection)
		next unless [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex].include?(classify_intersection)

		intersection
	  end
		
      intersection_points.compact!
      
	  #erase hits that are too close together at the edge of two faces
      #not needed with the Dave Method implemented
      # if a is less than .002 from a+1 then delete a
	  #(intersection_points.length - 1).times do |a|
	  #  next if (intersection_points[a].x - intersection_points[a+1].x).abs > 0.002
	  #  next if (intersection_points[a].y - intersection_points[a+1].y).abs > 0.002
	  #  next if (intersection_points[a].z - intersection_points[a+1].z).abs > 0.002
	  #  intersection_points[a] = nil 
	  # end
	  #intersection_points.compact!
     
     
	  intersection_points = intersection_points.inject([]){ |a, p0| a.any?{ |p| p == p0 } ? a : a << p0 }
      intersection_points.size.odd?
    end
    
    
    # Check if a Group or ComponentInstance is solid. If every edge binds an
    # even faces it is considered a solid. Nested groups and components are
    # ignored.
    #
    # container - The Group or ComponentInstance to test.
    #
    # Returns nil if not a Group or Component || if entities.length == 0
    #      then true/false if each edges is attached to an even number of faces
    def self.is_solid?(container)
      return unless [Sketchup::Group, Sketchup::ComponentInstance].include?(container.class)
      ents = entities(container)
      # return nil if the container is empty
      return if ents.length == 0
      !ents.any? { |e| e.is_a?(Sketchup::Edge) && e.faces.size.odd? }
    end
    
  end

end