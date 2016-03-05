LoadFunctionLibrary ("DNA.bf");
LoadFunctionLibrary ("parameters.bf");
LoadFunctionLibrary ("frequencies.bf");
LoadFunctionLibrary ("../UtilityFunctions.bf");

//------------------------------------------------------------------------------ 


function model.applyModelToTree (id, tree, model_list, rules) {

	if (Type (rules) == "AssociativeList") {
	    // this has the form 
	    // model id : list of branches to apply the model (as a string matrix)
	    // OR 
	    // DEFAULT : model id
	    
	    if (Abs (rules["DEFAULT"])) {
            ExecuteCommands ("UseModel (" + rules["DEFAULT"] + ");
                              Tree `id` = " + tree["string"] + ";
                              ");	    
	    } else {
            ExecuteCommands ("UseModel (USE_NO_MODEL);
                              Tree `id` = " + tree["string"] + ";
                              ");	    
	    
	    }
	    
	    model.applyModelToTree.ids = Rows (rules);
	    for (model.applyModelToTree.k = 0; model.applyModelToTree.k < Abs (rules); model.applyModelToTree.k += 1) {
	        model.applyModelToTree.name = model.applyModelToTree.ids[model.applyModelToTree.k];
	        if ( model.applyModelToTree.name != "DEFAULT") {
                model.applyModelToTree.list = rules[model.applyModelToTree.name];
                if (Type (model.applyModelToTree.list) == "AssociativeList") {
                    model.applyModelToTree.list = Rows (model.applyModelToTree.list);
                }
                
                if (Type (model_list) == "AssociativeList") {
                    model.applyModelToTree.apply_model = model_list[model.applyModelToTree.name];
                } else {
                    model.applyModelToTree.apply_model = model.applyModelToTree.name;
                }
                
                for (model.applyModelToTree.b = 0; model.applyModelToTree.b < Columns (model.applyModelToTree.list); model.applyModelToTree.b += 1) {
                    //fprintf (stdout, "SetParameter (`id`." + model.applyModelToTree.list[model.applyModelToTree.b] + ",MODEL," + model.applyModelToTree.apply_model + ")", "\n");
                    ExecuteCommands ("SetParameter (`id`." + model.applyModelToTree.list[model.applyModelToTree.b] + ",MODEL," + model.applyModelToTree.apply_model + ")");
                }
            }
	    }
	    
	} else {
		model.applyModelToTree.modelID = model_list[model_list ["INDEXORDER"][0]];
		ExecuteCommands ("UseModel (" + model.applyModelToTree.modelID["id"] + ");
						  Tree `id` = " + tree["string"] + ";
						  ");
	}
}


function model.define.from.components (id,q,efv,canonical) {
	ExecuteCommands ("Model `id` = (" + q + "," + efv + "," + canonical + ")");

}

//------------------------------------------------------------------------------ 


function model.generic.add_global (model_spec, id, tag) {
    ((model_spec["parameters"])[terms.global])[tag] = id;
}

lfunction model.generic.get_local_parameter (model_spec, tag) {
   return model.generic.get_a_parameter (model_spec, tag, ^"terms.local");
}

lfunction model.generic.get_global_parameter (model_spec, tag) {
   return model.generic.get_a_parameter (model_spec, tag, ^"terms.global");
}


lfunction model.generic.get_a_parameter (model_spec, tag, type) {
    v = ((model_spec["parameters"])[type])[tag];
    if (Type (v) == "String") {
        return v;
    }
    return None;
}




function model.generic.define_model (model_spec, id, arguments, data_filter, estimator_type) {
	
	model.generic.define_model.model = utility.callFunction (model_spec, arguments);	
	models.generic.attachFilter (model.generic.define_model.model, data_filter);
	
	model.generic.define_model.model = utility.callFunction(model.generic.define_model.model ["defineQ"], {"0" :   "model.generic.define_model.model",
																						   "1" :    parameters.quote (id)});
																						   
	model.generic.define_model.model ["matrix-id"] = "`id`_" + terms.rate_matrix;
	model.generic.define_model.model ["efv-id"] = "`id`_" + terms.efv_matrix;
	model.generic.define_model.model ["id"] = id;
		
	if (estimator_type != None) {
		model.generic.define_model.model ["frequency-estimator"] = estimator_type;
	} 
		
	utility.callFunction (model.generic.define_model.model ["frequency-estimator"], {"0": "model.generic.define_model.model", 
													    "1":  parameters.quote(id),
													    "2":  parameters.quote(data_filter)}); // this sets the EFV field
													    
					
	parameters.stringMatrixToFormulas (model.generic.define_model.model ["matrix-id"],model.generic.define_model.model[terms.rate_matrix]);
	utility.setEnvVariable (model.generic.define_model.model ["efv-id"], model.generic.define_model.model[terms.efv_estimate]);
		    
	model.define.from.components (id, 	model.generic.define_model.model ["matrix-id"], model.generic.define_model.model ["efv-id"], model.generic.define_model.model ["canonical"]);
    
    if (Type (model.generic.define_model.model["post-definition"]) == "String") {
        utility.callFunction (model.generic.define_model.model["post-definition"], {"0" : "model.generic.define_model.model"});
    }
	
	return model.generic.define_model.model;
}

//------------------------------------------------------------------------------ 

function models.generic.post.definition  (model) {
    if (Type (model ["id"]) == "String") {
        ExecuteCommands ("GetString (models.generic.post.definition.bl,"+model ["id"]+",-1)");
        model ["branch-length-string"] = models.generic.post.definition.bl; 
    }
    return model;
}

//------------------------------------------------------------------------------ 

function models.generic.set_branch_length (model, value, parameter) {
    if (Abs((model["parameters"])["local"]) == 1) {
        if (Type (model ["branch-length-string"]) == "String") {
            models.generic.set_branch_length.bl = (Columns ((model["parameters"])["local"]))[0];
            if (Type (value) == "AssociativeList") {
                ExecuteCommands ("FindRoot (models.generic.set_branch_length.t,(" + model ["branch-length-string"] + ")-" + value[terms.branch_length] + "," + models.generic.set_branch_length.bl + ",0,10000)");
                Eval (parameter + "." + models.generic.set_branch_length.bl + ":=(" + value[terms.branch_length_scaler] + ")*" + models.generic.set_branch_length.t);
                //fprintf (stdout, parameter + "." + models.generic.set_branch_length.bl + ":=(" + value[terms.branch_length_scaler] + ")*" + models.generic.set_branch_length.t, "\n");
                return 1;
           
            } else {
                ExecuteCommands ("FindRoot (models.generic.set_branch_length.t,(" + model ["branch-length-string"] + ")-" + value + "," + models.generic.set_branch_length.bl + ",0,10000)");
                Eval (parameter + "." + models.generic.set_branch_length.bl + "=" + models.generic.set_branch_length.t);
           }
        }
    }
    return 0;
}



//------------------------------------------------------------------------------ 

lfunction models.generic.attachFilter (model, filter) {

    if (Type (filter) != "String") {
        utility.forEach (filter, "_filter_", "models.generic.attachFilter (`&model`, _filter_)");
        model["data"] = filter;
        return model;
    } 

	GetDataInfo (givenAlphabet, ^filter, "CHARACTERS");
	alphabet = model ["alphabet"];

	assert (Columns (alphabet) == Columns (givenAlphabet) && model.matchAlphabets (givenAlphabet, alphabet), "The declared model alphabet '" +alphabet + "' does not match the `filter` filter: '" + givenAlphabet + "'");
	
	model ["alphabet"] = givenAlphabet;
	model ["data"] = filter;
	return model;
}

//------------------------------------------------------------------------------ 

function model.dimension (model) {
    if (Type (model["alphabet"]) == "Matrix") {
        return Columns (model["alphabet"]);
    }
    return None;
}

//------------------------------------------------------------------------------ 

function model.parameters.local (model) {
    return (model["parameters"])["local"];
}


//------------------------------------------------------------------------------ 

function model.parameters.global (model) {
    return (model["parameters"])["global"];
}

//------------------------------------------------------------------------------ 

lfunction model.matchAlphabets (a1, a2) {


	_validStates = {};
	for (_k = 0; _k < Columns (a1); _k += 1) {
		_validStates [a1[_k]] = _k;
	}
	for (_k = 0; _k < Columns (a2); _k += 1) {
		if (_validStates [a2[_k]] != _k) {
			return 0;
		}
	}
	return 1;

}