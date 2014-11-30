Simulations:
  - name: sim1
    time_integrator: ti_1
    optimizer: opt1

linear_solvers:

  - name: solve_scalar
    type: tpetra
    method: gmres
    preconditioner: sgs
    tolerance: 1e-5
    max_iterations: 50
    kspace: 50
    output_level: 0

  - name: solve_cont
    type: epetra
    method: gmres
    preconditioner: ML
    tolerance: 1e-5
    max_iterations: 50
    kspace: 50
    output_level: 0

transfers:

  - name: xfer_fluid_pmr_vol
    type: geometric
    realm_pair: [realm_2, realm_1]
    mesh_part_pair: [block_1, block_1]
    transfer_variables:
      - [temperature, temperature]
     
  - name: xfer_pmr_fluid
    type: geometric
    realm_pair: [realm_1, realm_2]
    mesh_part_pair: [block_1, block_1]
    transfer_variables:
      - [div_radiative_heat_flux, div_radiative_heat_flux]
     
realms:

  - name: realm_1
    mesh: pmrA_mks.g
    use_edges: yes 
    solve_frequency: 10

    equation_systems:
      name: theEqSys
      max_iterations: 10 
    
      solver_system_specification:
        intensity: solve_scalar

      systems:
        - RadiativeTransport:
            name: myRTE
            max_iterations: 1 
            convergence_tolerance: 1.e-3
            quadrature_order: 2 

    boundary_conditions:

    - periodic_boundary_condition: bc_left_right
      target_name: [surface_1, surface_2]
      periodic_user_data:
        search_tolerance: 1.e-5
        search_method: boost_rtree

    - wall_boundary_condition: bc_3
      target_name: surface_3
      wall_user_data:
        temperature: 400.0
        transmissivity: 0.0
        emissivity: 1.0 

    - wall_boundary_condition: bc_4
      target_name: surface_4
      wall_user_data:
        temperature: 300.0
        transmissivity: 0.0
        emissivity: 1.0 

    initial_conditions:

      - constant: ic_1
        target_name: block_1
        value:
          temperature: 300.0

    material_properties:
      target_name: block_1
      specifications:
        - name: absorption_coefficient
          type: constant
          value: 100.0

    solution_options:
      name: myOptions
      options:
        - user_constants:
            stefan_boltzmann: 5.6704e-8

    output:
      output_data_base_name: pmr.e
      output_frequency: 2
      output_node_set: no
      output_variables:
       - temperature
       - wall_temperature
       - absorption_coefficient
       - scalar_flux
       - radiative_heat_flux
       - div_radiative_heat_flux
       - irradiation

  - name: realm_2
    mesh: pmrA_mks_R1.g
    use_edges: yes 

    equation_systems:
      name: theEqSys
      max_iterations: 1

      solver_system_specification:
        velocity: solve_scalar
        pressure: solve_cont
        enthalpy: solve_scalar

      systems:

        - LowMachEOM:
            name: myLowMach
            max_iterations: 1
            convergence_tolerance: 1e-5

        - Enthalpy:
            name: myEnth
            max_iterations: 1
            convergence_tolerance: 1e-5

    material_properties:

      target_name: block_1

      constant_specification:
       universal_gas_constant: 8314.4621
       reference_pressure: 101325.0

      reference_quantities:
        - species_name: FakeAir
          mw: 28.0
          mass_fraction: 1.0

      specifications:
 
        - name: density
          type: ideal_gas_t

        - name: viscosity
          type: polynomial
          coefficient_declaration:
           - species_name: FakeAir
             coefficients: [1.7894e-5, 273.11, 110.56]

        - name: specific_heat
          type: polynomial
          coefficient_declaration:
           - species_name: FakeAir
             low_coefficients: [3.298677000E+00, 1.408240400E-03, -3.963222000E-06, 
                                5.641515000E-09, -2.444854000E-12,-1.020899900E+03]
             high_coefficients: [3.298677000E+00, 1.408240400E-03, -3.963222000E-06,
                                 5.641515000E-09, -2.444854000E-12,-1.020899900E+03]

    initial_conditions:
      - constant: ic_1
        target_name: block_1
        value:
          pressure: 0
          velocity: [0,0,0]  
          temperature: 300.0
  
    boundary_conditions:

    - periodic_boundary_condition: bc_left_right
      target_name: [surface_1, surface_2]
      periodic_user_data:
        search_tolerance: 1.e-5
        search_method: boost_rtree

    - wall_boundary_condition: bc_inner
      target_name: surface_3
      wall_user_data:
        velocity: [0,0,0]
        temperature: 400.0

    - wall_boundary_condition: bc_outer
      target_name: surface_4
      wall_user_data:
        velocity: [0,0,0]
        temperature: 300.0

    solution_options:
      name: myOptions
      options:
        - hybrid_factor:
            velocity: 1.0
            enthalpy: 1.0

        - laminar_prandtl:
            enthalpy: 1.0

        - turbulent_prandtl:
            enthalpy: 1.0

        - source_terms:
            momentum: buoyancy
            continuity: density_time_derivative
            enthalpy: participating_media_radiation

        - user_constants:
            gravity: [0.0, -9.81, 0.0]
            reference_density: 1.13796

        - limiter:
            pressure: no
            velocity: no
            enthalpy: yes 

    output:
      output_data_base_name: fluid.e
      output_frequency: 5
      output_node_set: no
      output_variables:
       - velocity
       - temperature
       - div_radiative_heat_flux
       - enthalpy

Time_Integrators:
  - StandardTimeIntegrator:
      name: ti_1
      start_time: 0
      termination_time: 0.21
      time_step: 0.01
      time_stepping_type: fixed
      time_step_count: 0
      nonlinear_iterations: 1 

      realms:
        - realm_1
        - realm_2

      transfers:
        - xfer_fluid_pmr_vol
        - xfer_fluid_pmr_surf1
        - xfer_fluid_pmr_surf2
        - xfer_pmr_fluid