package oidc

import (
	"context"
	"fmt"
)

// VerifyResult is the verified identity extracted from an id_token. All fields
// are sourced from the validated token: Subject and Issuer come from the JWT
// registered claims (validated against the discovery doc issuer + audience);
// Email and EmailVerified come from the standard OIDC userinfo-in-id_token
// claims.
type VerifyResult struct {
	Provider      string
	Subject       string
	Email         string
	EmailVerified bool
	Issuer        string
}

// idClaims is the subset of id_token claims we surface via VerifyResult. Only
// the OIDC-standard email claims are pulled here; subject/issuer are read
// directly from the validated *oidc.IDToken.
type idClaims struct {
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
}

// VerifyIDToken validates the id_token (extracted from the oauth2 token
// exchange response) and returns identity claims. Signature, iss, aud and exp
// are checked by the go-oidc verifier built in NewProvider against the
// provider's discovered JWKS and configured ClientID.
//
// Callers extract rawIDToken from the Exchange result via:
//
//	rawIDToken, _ := tok.Extra("id_token").(string)
func (p *Provider) VerifyIDToken(ctx context.Context, rawIDToken string) (*VerifyResult, error) {
	idToken, err := p.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("verify id_token: %w", err)
	}
	var c idClaims
	if err := idToken.Claims(&c); err != nil {
		return nil, fmt.Errorf("parse id_token claims: %w", err)
	}
	return &VerifyResult{
		Provider:      p.Config.Name,
		Subject:       idToken.Subject,
		Email:         c.Email,
		EmailVerified: c.EmailVerified,
		Issuer:        idToken.Issuer,
	}, nil
}
