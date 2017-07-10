# In this configuration, the Master App does not perform any finite element
# solve, so we can set the kernel coverage check to false. However, we
# cannot set the solve to false because this would turn off any evaluations
# of aux kernels.

[Problem]
  kernel_coverage_check = false
[]

[Mesh]
  type = GeneratedMesh
  dim = 1
  nx = 1
[]

[AuxVariables]
  [./l_0_flux_BC]
    family = SCALAR
    order = SIXTH
  [../]
  [./l_0_temp_BC]
    family = SCALAR
    order = SIXTH
  [../]
[]

[ICs]
  [./ic]
    type = ScalarComponentIC
    variable = 'l_0_temp_BC'
    values = '500.0 0.0 0.0 0.0 0.0 0.0'
  [../]
[]

[Variables]
  [./dummy]
  [../]
[]

[Executioner]
  type = Transient
  num_steps = 3
[]

[MultiApps]
  [./bison]
    type = TransientMultiApp
    app_type = BuffaloApp
    positions = '0 0 0'
    input_files = 'bison.i'
    execute_on = timestep_begin
#    library_path = /homes/anovak/projects/buffalo/lib
  [../]
  [./nek]
    type = TransientMultiApp
    app_type = MoonApp
    positions = '0 0 0'
    input_files = 'nek.i'
    execute_on = timestep_begin
    library_path = /homes/anovak/projects/moon/lib
  [../]
[]

[Outputs]
    exodus = true
[]
