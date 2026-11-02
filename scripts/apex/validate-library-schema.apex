List<LibrarySchemaValidation.Finding> findings=LibrarySchemaValidation.validate();
for(LibrarySchemaValidation.Finding finding: findings) System.debug(finding.status+' '+finding.target+' '+finding.detail);
Integer errors=0; for(LibrarySchemaValidation.Finding finding: findings) if(finding.status=='ERROR') errors++; System.assertEquals(0,errors,'Schema validation failed. Review the findings above.');
