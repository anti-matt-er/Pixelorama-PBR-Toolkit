extends Export


func export_processed_images(
	ignore_overwrites: bool, export_dialog: ConfirmationDialog, project := Global.current_project
) -> bool:
	var PBRExport = Global.get_node("/root/PBRExport")
	PBRExport.pre_export(project)
	var result = await super(ignore_overwrites, export_dialog, project)
	PBRExport.post_export(project)
	
	return result
