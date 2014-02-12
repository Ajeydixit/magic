LINK_OBJ = 	$(OBJDIR)/magic.o \
	$(OBJDIR)/truncation.o \
	$(OBJDIR)/m_phys_param.o \
	$(OBJDIR)/m_radial.o \
	$(OBJDIR)/m_num_param.o \
	$(OBJDIR)/m_TO.o \
	$(OBJDIR)/m_init_fields.o \
	$(OBJDIR)/m_Grenoble.o \
	$(OBJDIR)/m_blocking.o \
	$(OBJDIR)/m_horizontal.o \
	$(OBJDIR)/m_logic.o \
	$(OBJDIR)/m_mat.o \
	$(OBJDIR)/m_fields.o \
	$(OBJDIR)/m_dt_fieldsLast.o \
	$(OBJDIR)/m_movie.o \
	$(OBJDIR)/m_RMS.o \
	$(OBJDIR)/m_dtB.o \
	$(OBJDIR)/m_radialLoop.o \
	$(OBJDIR)/m_kinetic_energy.o \
	$(OBJDIR)/m_magnetic_energy.o \
	$(OBJDIR)/m_fields_average.o \
	$(OBJDIR)/m_Egeos.o \
	$(OBJDIR)/m_spectrum_average.o \
	$(OBJDIR)/m_spectrumC_average.o \
	$(OBJDIR)/m_output_data.o \
	$(OBJDIR)/m_output.o \
	$(OBJDIR)/m_outPV3.o \
	$(OBJDIR)/m_parallel.o \
	$(OBJDIR)/m_const.o \
	$(OBJDIR)/m_Bext.o \
	$(OBJDIR)/m_outTO.o

$(OBJDIR)/magic.o: $(OBJDIR)/truncation.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_TO.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_init_fields.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_Grenoble.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_mat.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_fields.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_dt_fieldsLast.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_movie.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_RMS.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_dtB.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_radialLoop.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_kinetic_energy.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_magnetic_energy.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_fields_average.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_Egeos.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_spectrum_average.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_spectrumC_average.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_output.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_outPV3.o
$(OBJDIR)/magic.o: $(OBJDIR)/m_parallel.o
$(OBJDIR)/m_phys_param.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_radial.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_num_param.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_TO.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_init_fields.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_Grenoble.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_blocking.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_horizontal.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_mat.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_fields.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_dt_fieldsLast.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_movie.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_RMS.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_RMS.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_dtB.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_TO.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_dtB.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_radialLoop.o: $(OBJDIR)/m_parallel.o
$(OBJDIR)/m_output_data.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_kinetic_energy.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_movie.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_magnetic_energy.o: $(OBJDIR)/m_Bext.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_kinetic_energy.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_magnetic_energy.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_fields_average.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_Egeos.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_spectrum_average.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_spectrumC_average.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_output.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_fields.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_kinetic_energy.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_magnetic_energy.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_fields_average.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_spectrum_average.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_spectrumC_average.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_outTO.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_outPV3.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_output.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_TO.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_outTO.o: $(OBJDIR)/m_const.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/truncation.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_radial.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_phys_param.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_num_param.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_blocking.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_horizontal.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_logic.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_output_data.o
$(OBJDIR)/m_outPV3.o: $(OBJDIR)/m_output_data.o