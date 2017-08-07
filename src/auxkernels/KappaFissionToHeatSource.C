#include "KappaFissionToHeatSource.h"
#include <iostream>
#include <math.h>

template<>
InputParameters validParams<KappaFissionToHeatSource>()
{
  InputParameters params = validParams<AuxKernel>();
  params.addRequiredCoupledVar("kappa_fission_source",
    "Continuous field representing the kappa-fisison source (eV/source particle)");
  params.addRequiredParam<Real>("power", "initial pin power (W)");
  params.addParam<bool>("one_group_PKE", false, "whether to use a one delayed "
    "neutron group approximation for transient power");
  params.addCoupledVar("keff", "Name of the scalar aux variable "
    "holding keff");
  params.addRequiredParam<std::string>("volume_pp",
    "The name of the postprocessor that calculates volume.");
  return params;
}

KappaFissionToHeatSource::KappaFissionToHeatSource(const InputParameters & parameters) :
    AuxKernel(parameters),
    _kappa_fission(coupledValue("kappa_fission_source")),
    _power(parameters.get<Real>("power")),
    _one_group_PKE(getParam<bool>("one_group_PKE")),
    _volume_pp(getPostprocessorValueByName(parameters.get<std::string>("volume_pp")))
{
  if (isParamValid("keff"))
    _keff.push_back(&coupledScalarValue("keff", 0));
}

KappaFissionToHeatSource::~KappaFissionToHeatSource()
{
}

Real
KappaFissionToHeatSource::computeValue()
{
  /* This converts a kappa fission tally (units eV/source particle) to a
     volumetric heat source (W/cm^3) to be used in coupled simulations. To account
     for changes in power from the initial steady state power provided, a one
     delayed neutron group approximation is used with the point kinetics
     equations. The solution is taken for small reactivity changes from
     Duderstadt and Hamilton, "Reactor Theory," Chapter 6, Section II. This model
     assumes that:
       - the system begins at steady state (k ~ 1)
       - there is only one delayed neutron group

     In addition to these one-group-specific assumptions, the assumptions made
     in the derivation of the PKE are:
       - the diffusion equation is valid
          - flux is at most linearly anisotropic in angle
          - changes in current are much smaller than the magnitude of current
       - the flux is separable in both space and time, and the spatial dependence
         is given by the first eigenfunction (characterized by the geometric
         buckling)
       - the delayed neutron precursor distribution has the same spatial
         distribution as the neutron population

     Note that this model is not intended to provide very accurate results, but
     only to provide some real-physics-like response to changes in temperature
     on the power for coupling to TH codes.

     TODO: make this more general by:
       - accounting for energy produced in the coolant (note this only
         accounts for energy produced in the fuel) */

     // The data used to compute beta, lambda, and Lambda are taken from:
     // http://nuclearpowertraining.tpub.com/h1019v2/css/
     // Table-1-Delayed-Neutron-Fractions-For-Various-Fuels-104.htm
     // for U-235 in a thermal system

  Real multiplier = 1.0;

  if (_one_group_PKE)
  {
    // fraction of neutrons born delayed (summed over all delayed groups)
    Real beta = 0.00645;

    // effective half life of all delayed groups
    Real lambda = 0.0771347;

    // effective neutron generation time, taken as a representative value
    // from page 243, Duderstadt & Hamilton
    Real Lambda = 10.0e-3;

    Real keff;
    if (isParamValid("keff"))
      keff = (*_keff[0])[0];
    else
      keff = 1.0;

    // reactivity
    Real rho = (keff - 1.0) / keff;

    Real term1 = Lambda * lambda + beta - rho;
    Real term2 = term1 * term1 + 4 * Lambda * lambda * rho;
    Real w1 = (- term1 + sqrt(term2)) / (2 * Lambda);
    Real w2 = (- term1 - sqrt(term2)) / (2 * Lambda);

    Real term3 = ((w1 + lambda) * w2 / (lambda * (w2 - w1))) * exp(w1 * _t);
    Real term4 = ((w2 + lambda) * w1 / (lambda * (w1 - w2))) * exp(w2 * _t);

    multiplier = term3 + term4;
    if (multiplier < 0) mooseWarning("Negative fission power multiplier!");
  }

  Real E_per_fission = 200.0E6;
  Real particles_per_fission = 2.45;
  return _kappa_fission[_qp] * multiplier * _power * particles_per_fission /
    (E_per_fission * _volume_pp);
}
